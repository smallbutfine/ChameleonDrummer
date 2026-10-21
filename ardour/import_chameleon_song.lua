--[[
  ChameleonDrummer -> Ardour session builder (headless).

  Run with Ardour's standalone Lua interpreter:

      ardour9-lua ardour/import_chameleon_song.lua <data-file>

  The data file is a Lua chunk written by the ChameleonDrummer exporter
  (src/ArdourAPI.pas). It returns a table like:

      return {
        session_dir  = "C:/out/MySong.ardour",   -- must NOT exist
        session_name = "MySong",
        sample_rate  = 48000,
        title        = "metal_death_bonham",
        midi_file    = "C:/out/MySong.mid",
        total_beats  = 415.5,
        tempo_points = { { beat = 0, bpm = 180, beats_per_bar = 4 } },
        sections     = { { name = "intro", start_beat = 0, end_beat = 16 } },
      }

  What this script does:

    1. creates a real Ardour session directory (headless, dummy audio backend)
    2. adds a MIDI track
    3. writes the tempo map
    4. adds one range location (region) and one point marker per song section
    5. saves the session
    6. copies the generated MIDI file into the session's interchange directory
    7. patches the saved session state so the MIDI region is present and the
       point markers carry the "IsMark" flag

  Steps 1-5 use Ardour's own Lua API. Steps 6-7 are needed because Ardour's
  public Lua API cannot create a MIDI region from a file (only the GUI's
  Editor:do_import can) and cannot set the location flags (only the GUI's
  Editor:add_location_mark can). Both patches are applied to the state file
  Ardour itself has just written, using the exact element layout Ardour uses.
]]

local data_path = arg and arg[1]
if not data_path then
  print("usage: ardour9-lua import_chameleon_song.lua <data-file>")
  return
end

local d = dofile(data_path)
if not d then
  print("error: could not read data file " .. tostring(data_path))
  return
end

-- Beat positions are Ardour's native domain: 1 beat = Temporal.ticks_per_beat
-- (= 1920) units, and the session state stores them as "b<beats*1920>".
local TPB = Temporal.ticks_per_beat

local function beatpos(beats)
  return Temporal.timepos_t.from_ticks(TPB * beats)
end

local function beatunits(beats)
  return math.floor(beats * TPB + 0.5)
end

-- ---------------------------------------------------------------------------
-- 1. create the session
-- ---------------------------------------------------------------------------
-- create_session() refuses to run when the session directory already exists,
-- so the exporter must not have created it.
if d.session_dir and d.session_name then
  create_session(d.session_dir, d.session_name, d.sample_rate or 48000)
end

if not Session then
  print("error: could not create session " .. tostring(d.session_dir))
  return
end

print("chameleon: session created at " .. tostring(d.session_dir))

-- ---------------------------------------------------------------------------
-- 2. MIDI track
-- ---------------------------------------------------------------------------
local cc = ARDOUR.ChanCount(ARDOUR.DataType.audio(), 0)
local tracks = Session:new_midi_track(cc, cc, false, ARDOUR.PluginInfo(), nil,
                                      ARDOUR.RouteGroup(), 1, "Drums",
                                      ARDOUR.PresentationInfo.max_order,
                                      ARDOUR.TrackMode.Normal, true)
if not tracks then
  print("error: could not create MIDI track")
  return
end

-- ---------------------------------------------------------------------------
-- 3. tempo map
-- ---------------------------------------------------------------------------
if d.tempo_points and #d.tempo_points > 0 then
  local tm = Temporal.TempoMap.write_copy()
  for _, tp in ipairs(d.tempo_points) do
    tm:set_tempo(Temporal.Tempo(tp.bpm, tp.bpm, tp.beats_per_bar or 4),
                 beatpos(tp.beat))
  end
  Temporal.TempoMap.update(tm)
  print("chameleon: tempo map written (" .. #d.tempo_points .. " points)")
end

-- ---------------------------------------------------------------------------
-- 4. locations: one range (region) and one point marker per section
-- ---------------------------------------------------------------------------
local locs = Session:locations()
local marker_positions = {}

for _, sec in ipairs(d.sections or {}) do
  local start = beatpos(sec.start_beat)
  local stop = beatpos(sec.end_beat)

  -- the region: covers the whole section
  local region = locs:add_range(start, stop)
  if region then
    region:set_name(sec.name)
  end

  -- the marker: a zero-length location at the section start. Ardour's Lua API
  -- cannot set the "IsMark" flag, so it is created as an empty range and
  -- converted to a real marker when the session state is patched below.
  local marker = locs:add_range(start, start)
  if marker then
    marker:set_name(sec.name)
  end
  table.insert(marker_positions, sec.start_beat)
end

print("chameleon: " .. #(d.sections or {}) .. " sections added")

-- ---------------------------------------------------------------------------
-- 5. save the session
-- ---------------------------------------------------------------------------
Session:save_state("")
print("chameleon: session saved")

-- ---------------------------------------------------------------------------
-- 6. copy the MIDI file into the session's interchange directory
-- ---------------------------------------------------------------------------
-- Ardour names the interchange sub-directory after the session *directory*,
-- not after the session name.
local session_basename = d.session_dir:match("([^/\\]+)[/\\]*$") or d.session_name
local midifiles = d.session_dir .. "/interchange/" .. session_basename .. "/midifiles/"

local function copy_file(src, dst)
  local fi = io.open(src, "rb")
  if not fi then
    return false, "cannot open " .. src
  end
  local content = fi:read("*a")
  fi:close()
  local fo = io.open(dst, "wb")
  if not fo then
    return false, "cannot write " .. dst
  end
  fo:write(content)
  fo:close()
  return true
end

local midi_name = d.midi_file and d.midi_file:match("[^/\\]+$") or "chameleon.mid"
if d.midi_file then
  local ok, err = copy_file(d.midi_file, midifiles .. midi_name)
  if not ok then
    print("error: could not copy MIDI file: " .. tostring(err))
    return
  end
  print("chameleon: MIDI copied to " .. midifiles .. midi_name)
end

-- ---------------------------------------------------------------------------
-- 7. patch the saved session state
-- ---------------------------------------------------------------------------
local state_file = d.session_dir .. "/" .. d.session_name .. ".ardour"

local function read_file(path)
  local f = io.open(path, "rb")
  if not f then
    return nil
  end
  local c = f:read("*a")
  f:close()
  return c
end

local function write_file(path, content)
  local f = io.open(path, "wb")
  if not f then
    return false
  end
  f:write(content)
  f:close()
  return true
end

-- 7a. the MIDI region. The region references a <Source> of type "midi" whose
-- "origin" is the path of the .mid file inside the session directory.
if d.midi_file then
  local state = read_file(state_file)
  if state then
    local source_id = "900001"
    local region_id = "900002"
    local total = beatunits(d.total_beats or 0)
    local origin = "interchange/" .. session_basename .. "/midifiles/" .. midi_name

    local source_node = '<Source name="' .. midi_name ..
      '" take-id="" type="midi" flags="" id="' .. source_id ..
      '" natural-position="b0" origin="' .. origin .. '"/>'

    if state:find("<Sources/>", 1, true) then
      state = state:gsub("<Sources/>", "<Sources>" .. source_node .. "</Sources>", 1)
    else
      state = state:gsub("</Sources>", source_node .. "</Sources>", 1)
    end

    -- the region goes into the MIDI track's playlist
    local region_node = '<Region name="ChameleonDrummer" muted="0" opaque="1"' ..
      ' locked="0" video-locked="0" automatic="0" whole-file="1" import="0"' ..
      ' external="0" sync-marked="0" left-of-split="0" right-of-split="0"' ..
      ' hidden="0" position-locked="0" valid-transients="0" start="b0"' ..
      ' length="b' .. total .. '@b0" sync-position="b0" ancestral-start="b0"' ..
      ' ancestral-length="b0@b0" stretch="1" shift="1" layering-index="0"' ..
      ' tags="" contents="0" rgroup="0" envelope-active="0" default-fade-in="0"' ..
      ' default-fade-out="0" fade-in-active="1" fade-out-active="1"' ..
      ' fade-before-fx="0" scale-amplitude="1" id="' .. region_id ..
      '" type="midi" first-edit="nothing" source-0="' .. source_id ..
      '" master-source-0="' .. source_id .. '" channels="1"/>'

    local pl_start = state:find("<Playlist ", 1, true)
    if pl_start then
      local pl_end = state:find("/>", pl_start, true)
      if pl_end then
        state = state:sub(1, pl_end - 1) .. ">" .. region_node .. "</Playlist>" ..
                state:sub(pl_end + 2)
      end
    end

    -- 7b. point markers: a location whose start and end are identical is one
    -- of the marker stubs, and must carry the "IsMark" flag. The section
    -- ranges keep "IsRangeMarker".
    state = state:gsub("<Location ([^>]-)/>", function(tag)
      local s = tag:match('start="([^"]*)"')
      local e = tag:match('end="([^"]*)"')
      if s and e and s == e then
        tag = tag:gsub('flags="IsRangeMarker"', 'flags="IsMark"')
      end
      return "<Location " .. tag .. "/>"
    end)

    write_file(state_file, state)
    print("chameleon: session state patched (MIDI region + markers)")
  else
    print("error: could not read session state " .. state_file)
    return
  end
end

close_session()
print("chameleon: done")
