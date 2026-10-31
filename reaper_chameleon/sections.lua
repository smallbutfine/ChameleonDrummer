-- reaper_chameleon/sections.lua
-- Business logic for the Song Sections tab and timeline import.
-- Builds CLI commands for ChameleonDrummer, creates REAPER regions,
-- and imports generated MIDI.

local M = {}

function M.get_project_dir()
  local p = reaper.GetProjectPath("")
  return (p ~= "") and p or reaper.GetResourcePath()
end

function M.shell_escape(s)
  s = s:gsub("[\r\n]", " ")
  s = s:gsub('"', "'")
  s = s:gsub("[&|^<>%%]", "")
  return s
end

{ Build the generate command for Song Sections mode.
  Uses existing CLI flags exactly like the GUI app does. }
function M.build_template_cmd(exe, genre, style, mapping, midi_out, drummer, intensity, tempo, bars)
  local drummer_flag = ""
  if drummer and drummer ~= "" then
    drummer_flag = string.format(' --drummer "%s" --drummer-intensity %g', M.shell_escape(drummer), intensity)
  end
  local tempo_flag = ""
  if tempo and tempo > 0 then
    tempo_flag = string.format(' --tempo %d', tempo)
  end
  local bars_flag = ""
  if bars and bars > 0 then
    bars_flag = string.format(' --bars %d', bars)
  end
  return string.format(
    '"%s" generate --genre "%s" --style "%s" --mapping "%s" --output "%s"%s%s%s',
    M.shell_escape(exe), M.shell_escape(genre), M.shell_escape(style),
    M.shell_escape(mapping), midi_out, drummer_flag, tempo_flag, bars_flag
  )
end

{ Create REAPER regions from a list of sections. }
function M.create_regions_from_sections(sections, bpm, ts_num, ts_den)
  local measure_length = (60.0 / bpm) * ts_num * (4.0 / ts_den)
  reaper.Undo_BeginBlock()
  local current_time = 0.0
  for _, s in ipairs(sections) do
    local region_end = current_time + (s.bars * measure_length)
    reaper.AddProjectMarker2(0, true, current_time, region_end, s.name, -1, 0)
    current_time = region_end
  end
  reaper.Undo_EndBlock("Create Song Sections as Regions", -1)
  reaper.UpdateArrange()
end

{ Apply timeline (tempo points + regions) to REAPER from additive rhythm output. }
function M.apply_timeline_to_reaper(tempo_points, regions, color_groups)
  reaper.Undo_BeginBlock()
  for _, tp in ipairs(tempo_points) do
    reaper.SetTempoTimeSigMarker(0, -1, tp.time, -1, -1, tp.bpm, tp.num, tp.denom, false)
  end
  for _, r in ipairs(regions) do
    local color = 0
    local cg = color_groups[r.color_group]
    if cg then
      color = reaper.ColorToNative(cg.r, cg.g, cg.b) | 0x1000000
    end
    reaper.AddProjectMarker2(0, true, r.start_time, r.end_time, r.name, -1, color)
  end
  reaper.Undo_EndBlock("Create Song Sections from Timeline", -1)
  reaper.UpdateArrange()
end

{ Import a MIDI file into the current REAPER project. }
function M.import_midi(midi_path)
  reaper.InsertMedia(midi_path, 0)
  reaper.UpdateArrange()
end

{ Parse timeline JSON output from additive-rhythm command.
  Returns tempo_points, regions, color_groups or nil on error. }
function M.parse_timeline(content)
  local tempo_points = {}
  for time, bpm, num, denom in content:gmatch(
    '"time"%s*:%s*([%-%d%.]+)%s*,%s*"bpm"%s*:%s*([%-%d%.]+)%s*,'
    .. '%s*"num"%s*:%s*(%d+)%s*,%s*"denom"%s*:%s*(%d+)'
  ) do
    tempo_points[#tempo_points + 1] = {
      time = tonumber(time), bpm = tonumber(bpm),
      num = tonumber(num), denom = tonumber(denom),
    }
  end

  local regions = {}
  for name, color_group, start_time, end_time in content:gmatch(
    '"name"%s*:%s*"([^"]*)"%s*,%s*"color_group"%s*:%s*"([^"]*)"%s*,'
    .. '%s*"start_time"%s*:%s*([%-%d%.]+)%s*,%s*"end_time"%s*:%s*([%-%d%.]+)'
  ) do
    regions[#regions + 1] = {
      name = name, color_group = color_group,
      start_time = tonumber(start_time), end_time = tonumber(end_time),
    }
  end

  local color_groups = {}
  for name, r, g, b in content:gmatch(
    '"name"%s*:%s*"([^"]*)"%s*,%s*"r"%s*:%s*(%d+)%s*,'
    .. '%s*"g"%s*:%s*(%d+)%s*,%s*"b"%s*:%s*(%d+)'
  ) do
    color_groups[name] = { r = tonumber(r), g = tonumber(g), b = tonumber(b) }
  end

  if #tempo_points == 0 then
    return nil, "No tempo points found in timeline"
  end
  return tempo_points, regions, color_groups
end

return M
