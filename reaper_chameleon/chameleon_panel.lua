-- reaper_chameleon/chameleon_panel.lua
-- ChameleonDrummer REAPER panel. ReaImGui dockable window with tabs:
-- Song Sections, Additive Rhythm, Settings, Log.
--
-- Generates drum MIDI via the ChameleonDrummer CLI and imports it into
-- the current REAPER project.

local script_path = ({ reaper.get_action_context() })[2]:match("^(.*[/\\])")
package.path = package.path .. ";" .. script_path .. "?.lua"

local job_runner = dofile(script_path .. "job_runner.lua")
local settings = dofile(script_path .. "settings.lua")
local options = dofile(script_path .. "options.lua")
local sections = dofile(script_path .. "sections.lua")
local additive_rhythm = dofile(script_path .. "additive_rhythm.lua")

local ctx = reaper.ImGui_CreateContext("ChameleonDrummer")

local FONT_SANS_SIZE = 14
local FONT_MONO_SIZE = 13
local font_sans = reaper.ImGui_CreateFont("Segoe UI", FONT_SANS_SIZE)
local font_mono = reaper.ImGui_CreateFont("Consolas", FONT_MONO_SIZE)
if font_sans then reaper.ImGui_Attach(ctx, font_sans) end
if font_mono then reaper.ImGui_Attach(ctx, font_mono) end

local help_popover_open = {}

local function draw_help_button(id, lines)
  reaper.ImGui_SameLine(ctx)
  reaper.ImGui_TextColored(ctx, 0xa78bfaff, "(?)")
  if reaper.ImGui_IsItemClicked(ctx) then
    reaper.ImGui_OpenPopup(ctx, "help_popup_" .. id)
  end
  if reaper.ImGui_BeginPopup(ctx, "help_popup_" .. id) then
    for _, entry in ipairs(lines) do
      reaper.ImGui_TextColored(ctx, 0xa78bfaff, entry.title)
      reaper.ImGui_TextWrapped(ctx, entry.body)
      reaper.ImGui_Separator(ctx)
    end
    reaper.ImGui_EndPopup(ctx)
  end
end

local function combo_from_list(label, current_value, items, empty_label)
  local changed = false
  local new_value = current_value
  local preview = current_value
  if preview == "" and empty_label then
    preview = empty_label
  end
  if reaper.ImGui_BeginCombo(ctx, label, preview) then
    if empty_label then
      local is_selected = (current_value == "")
      if reaper.ImGui_Selectable(ctx, empty_label, is_selected) then
        new_value = ""
        changed = true
      end
      if is_selected then reaper.ImGui_SetItemDefaultFocus(ctx) end
    end
    for _, item in ipairs(items) do
      local is_selected = (item == current_value)
      if reaper.ImGui_Selectable(ctx, item, is_selected) then
        new_value = item
        changed = true
      end
      if is_selected then reaper.ImGui_SetItemDefaultFocus(ctx) end
    end
    reaper.ImGui_EndCombo(ctx)
  end
  return changed, new_value
end

local GRID_VALUES = { "4", "8", "16", "32" }

local function cached_python_exe()
  local exe = settings.get("python_exe")
  if exe == "" then return nil end
  local f = io.open(exe, "rb")
  if not f then return nil end
  f:close()
  return exe
end

local function refresh_options()
  if job_runner.is_running() then return end
  local python_exe = cached_python_exe()
  if not python_exe then return end

  local cmd = options.build_cmd(python_exe)
  job_runner.start(cmd, "Load Options", function()
    local content = table.concat(job_runner.state.log_lines, "\n")
    local parsed, err = options.parse(content)
    if parsed then
      options.cache_options(parsed)
    else
      options.cache_error(err or "Could not parse options JSON.")
    end
  end)
end

-- ===== Song Sections tab state =====
local ss_mode = 1 -- 1=generate only
local ss_genre = settings.get("default_genre")
local ss_style = settings.get("default_style")
local ss_mapping = settings.get("default_mapping")
local ss_drummer = ""
local ss_drummer_intensity = 1.0
local ss_tempo = tonumber(settings.get("default_tempo")) or 120
local ss_bars = tonumber(settings.get("default_bars")) or 8
local ss_status = ""

local SS_MODE_HELP = {
  { title = "Generate", body = "Generate a drum pattern using the selected "
    .. "genre, style, drummer, and mapping. Creates REAPER regions matching "
    .. "the section structure and imports the MIDI file." },
}

local DRUMMER_INTENSITY_HELP = {
  { title = "Drummer Intensity", body = "How strongly the drummer's "
    .. "signature style overrides the genre pattern. 1.0 = full drummer "
    .. "character (default). Lower it toward 0.0 to keep more of the "
    .. "genre plugin's own identity." },
}

-- ===== Additive Rhythm tab state =====
local ar_grouping = settings.get("ar_grouping") or "3-3-3-3-2-2"
local ar_grid = settings.get("ar_grid") or "16"
local ar_tempo = settings.get("ar_tempo") or "120"
local ar_drummer = settings.get("ar_drummer") or ""
local ar_drummer_intensity = tonumber(settings.get("ar_drummer_intensity")) or 1.0
local ar_mapping = settings.get("ar_mapping") or settings.get("default_mapping") or "gm"
local ar_write_timeline = false
local ar_status = ""

local AR_GROUPING_HELP = {
  { title = "Additive Rhythm (box notation)", body = "Converts a grouping "
    .. "string into per-bar time signatures and a matching drum pattern. "
    .. "Groups are separated by '-' or '+'. '|' marks an explicit bar "
    .. "boundary. Examples: '3-3-3-3-2-2' (six bars of 3/8, 3/8, 3/8, "
    .. "3/8, 2/8, 2/8 at 16th grid), '3-3-3|3-3-2' (two bars: 9/8, 8/8), "
    .. "'2+2+3|' (one bar of 7/8). Kick on group downbeats, snare on "
    .. "backbeats, hi-hat continuous on grid." },
}

-- ===== Settings tab state =====
local function settings_field(label, key)
  local value = settings.get(key)
  local changed, new_value = reaper.ImGui_InputText(ctx, label, value)
  if changed then
    settings.set(key, new_value)
  end
end

local function draw_settings_tab()
  reaper.ImGui_Text(ctx, "ChameleonDrummer CLI path")
  local exe = settings.get("python_exe")
  reaper.ImGui_SetNextItemWidth(ctx, -170)
  local exe_changed, new_exe = reaper.ImGui_InputText(ctx, "##cli_path", exe)
  if exe_changed then
    settings.set("python_exe", new_exe)
  end
  reaper.ImGui_SameLine(ctx)
  if reaper.ImGui_Button(ctx, "Browse...") then
    local ok, picked = reaper.GetUserFileNameForRead(
      exe, "Select ChameleonDrummer.exe", ""
    )
    if ok and picked ~= "" then
      settings.set("python_exe", picked)
    end
  end

  reaper.ImGui_SameLine(ctx)
  reaper.ImGui_Text(ctx, "CLI exe path")

  local refresh_disabled = job_runner.is_running()
  if refresh_disabled then reaper.ImGui_BeginDisabled(ctx) end
  if reaper.ImGui_Button(ctx, "Refresh Options") then
    refresh_options()
  end
  if refresh_disabled then reaper.ImGui_EndDisabled(ctx) end
  reaper.ImGui_SameLine(ctx)
  if options.cache.loaded then
    reaper.ImGui_TextColored(ctx, 0x4ade80ff,
      string.format(
        "Loaded: %d genres, %d drummers, %d mappings",
        #options.cache.genres, #options.cache.drummers, #options.cache.mappings
      )
    )
  elseif options.cache.error then
    reaper.ImGui_TextColored(ctx, 0xfb7185ff, "Error: " .. options.cache.error)
  else
    reaper.ImGui_TextColored(ctx, 0x778ca6ff, "Not loaded yet.")
  end

  reaper.ImGui_Separator(ctx)
  reaper.ImGui_Text(ctx, "Defaults")
  settings_field("Default genre", "default_genre")
  settings_field("Default style", "default_style")
  settings_field("Default mapping", "default_mapping")
  settings_field("Default tempo", "default_tempo")
  settings_field("Default bars", "default_bars")

  reaper.ImGui_Separator(ctx)
  reaper.ImGui_TextWrapped(ctx,
    "ChameleonDrummer REAPER Panel - generates drum MIDI via the "
    .. "ChameleonDrummer CLI and imports it into this project. "
    .. "See REAPER_INTEGRATION_PLAN.md for details."
  )
end

local STATUS_COLORS = {
  idle = 0x778ca6ff,
  running = 0x38bdf8ff,
  done = 0x4ade80ff,
  error = 0xfb7185ff,
}

local function draw_log_tab()
  local st = job_runner.state
  reaper.ImGui_Text(ctx, "Job: " .. (st.job_label or "(none)"))
  reaper.ImGui_SameLine(ctx)
  reaper.ImGui_Text(ctx, string.format("(%.1fs)", job_runner.elapsed_seconds()))
  reaper.ImGui_SameLine(ctx)
  reaper.ImGui_TextColored(ctx, STATUS_COLORS[st.status] or STATUS_COLORS.idle, st.status)

  reaper.ImGui_Separator(ctx)

  if font_mono then reaper.ImGui_PushFont(ctx, font_mono, FONT_MONO_SIZE) end
  if reaper.ImGui_BeginChild(ctx, "log_box", 0, 300) then
    if #st.log_lines == 0 then
      reaper.ImGui_TextDisabled(ctx, "No job run yet.")
    else
      for _, line in ipairs(st.log_lines) do
        reaper.ImGui_TextWrapped(ctx, line)
      end
      if job_runner.is_running() then
        reaper.ImGui_SetScrollHereY(ctx, 1.0)
      end
    end
    reaper.ImGui_EndChild(ctx)
  end
  if font_mono then reaper.ImGui_PopFont(ctx) end
end

local function sidecar_path()
  local override = settings.get("sidecar_path_override")
  if override ~= "" then
    return override
  end
  return sections.get_project_dir() .. "/chameleon_sections.json"
end

local function midi_out_path(name)
  return sections.get_project_dir() .. "/" .. name
end

local function draw_song_sections_tab()
  reaper.ImGui_Text(ctx, "Genre:")
  local changed
  changed, ss_genre = combo_from_list("##ss_genre", ss_genre, options.cache.genres)
  local ss_styles = options.cache.genre_styles[ss_genre] or {}
  if changed then
    local style_ok = false
    for _, s in ipairs(ss_styles) do
      if s == ss_style then style_ok = true end
    end
    if not style_ok then
      ss_style = ss_styles[1] or ""
    end
  end

  reaper.ImGui_Text(ctx, "Style:")
  changed, ss_style = combo_from_list("##ss_style", ss_style, ss_styles)

  reaper.ImGui_Text(ctx, "Drummer (optional):")
  changed, ss_drummer = combo_from_list("##ss_drummer", ss_drummer, options.cache.drummers, "(none)")

  reaper.ImGui_Text(ctx, "Drummer Intensity:")
  changed, ss_drummer_intensity = reaper.ImGui_SliderDouble(ctx, "##ss_intensity", ss_drummer_intensity, 0.0, 1.0)
  draw_help_button("ss_drummer_intensity", DRUMMER_INTENSITY_HELP)

  reaper.ImGui_Text(ctx, "Mapping:")
  changed, ss_mapping = combo_from_list("##ss_mapping", ss_mapping, options.cache.mappings)

  reaper.ImGui_Text(ctx, "Tempo (BPM):")
  changed, ss_tempo = reaper.ImGui_InputInt(ctx, "##ss_tempo", ss_tempo)

  reaper.ImGui_Text(ctx, "Bars:")
  changed, ss_bars = reaper.ImGui_InputInt(ctx, "##ss_bars", ss_bars)

  reaper.ImGui_Separator(ctx)

  local disabled = job_runner.is_running()
  if disabled then reaper.ImGui_BeginDisabled(ctx) end
  if reaper.ImGui_Button(ctx, "Generate") then
    local python_exe = settings.resolve_python_exe()
    if not python_exe then
      ss_status = "Cancelled: no ChameleonDrummer CLI configured."
    else
      local sc_path = sidecar_path()
      local midi_out = midi_out_path("chameleon_song.mid")

      local default_sections = {
        { name = "Intro", bars = 4 },
        { name = "Verse", bars = 8 },
        { name = "Chorus", bars = 8 },
        { name = "Bridge", bars = 4 },
        { name = "Outro", bars = 4 },
      }
      local bpm = reaper.Master_GetTempo()
      local ts_num, ts_denom = reaper.GetProjectTimeSignature2(0)
      sections.create_regions_from_sections(default_sections, bpm, ts_num, ts_denom)

      local cmd = sections.build_template_cmd(
        python_exe, ss_genre, ss_style, ss_mapping, midi_out,
        ss_drummer, ss_drummer_intensity, ss_tempo, ss_bars
      )
      job_runner.start(cmd, "Song Sections", function()
        sections.import_midi(midi_out)
        ss_status = "Done."
      end)
      ss_status = "Running..."
    end
  end
  if disabled then reaper.ImGui_EndDisabled(ctx) end

  reaper.ImGui_TextWrapped(ctx, ss_status)
  if job_runner.is_running() then
    reaper.ImGui_TextWrapped(ctx, job_runner.state.job_label .. " - " .. job_runner.state.status)
  end
end

local function draw_additive_rhythm_tab()
  reaper.ImGui_Text(ctx, "Grouping:")
  local changed
  changed, ar_grouping = reaper.ImGui_InputText(ctx, "##ar_grouping", ar_grouping)
  draw_help_button("ar_grouping", AR_GROUPING_HELP)

  reaper.ImGui_Text(ctx, "Grid:")
  changed, ar_grid = combo_from_list("##ar_grid", ar_grid, GRID_VALUES)

  reaper.ImGui_Text(ctx, "Tempo (BPM):")
  changed, ar_tempo = reaper.ImGui_InputText(ctx, "##ar_tempo", ar_tempo)

  reaper.ImGui_Text(ctx, "Drummer (optional):")
  changed, ar_drummer = combo_from_list("##ar_drummer", ar_drummer, options.cache.drummers, "(none)")

  reaper.ImGui_Text(ctx, "Drummer Intensity:")
  changed, ar_drummer_intensity = reaper.ImGui_SliderDouble(ctx, "##ar_intensity", ar_drummer_intensity, 0.0, 1.0)
  draw_help_button("ar_drummer_intensity", DRUMMER_INTENSITY_HELP)

  reaper.ImGui_Text(ctx, "Mapping:")
  changed, ar_mapping = combo_from_list("##ar_mapping", ar_mapping, options.cache.mappings)

  reaper.ImGui_Text(ctx, "Write timeline JSON:")
  changed, ar_write_timeline = reaper.ImGui_Checkbox(ctx, "##ar_timeline", ar_write_timeline)

  reaper.ImGui_Separator(ctx)

  local disabled = job_runner.is_running()
  if disabled then reaper.ImGui_BeginDisabled(ctx) end
  if reaper.ImGui_Button(ctx, "Generate") then
    local python_exe = settings.resolve_python_exe()
    if not python_exe then
      ar_status = "Cancelled: no ChameleonDrummer CLI configured."
    else
      local tempo_num = tonumber(ar_tempo) or 120
      local midi_out = midi_out_path("chameleon_additive.mid")
      local timeline_path = sections.get_project_dir() .. "/chameleon_timeline.json"

      local cmd = additive_rhythm.build_cmd(
        python_exe, ar_grouping, ar_grid, tempo_num,
        ar_mapping, midi_out, ar_drummer, ar_drummer_intensity,
        ar_write_timeline, timeline_path
      )
      job_runner.start(cmd, "Additive Rhythm", function()
        sections.import_midi(midi_out)
        if ar_write_timeline then
          local f = io.open(timeline_path, "r")
          if f then
            local content = f:read("*a")
            f:close()
            local tempo_points, regions, color_groups = sections.parse_timeline(content)
            if tempo_points then
              sections.apply_timeline_to_reaper(tempo_points, regions, color_groups)
            end
          end
        end
        ar_status = "Done."
      end)
      ar_status = "Running..."
    end
  end
  if disabled then reaper.ImGui_EndDisabled(ctx) end

  reaper.ImGui_TextWrapped(ctx, ar_status)
  if job_runner.is_running() then
    reaper.ImGui_TextWrapped(ctx, job_runner.state.job_label .. " - " .. job_runner.state.status)
  end
end

local function loop()
  job_runner.poll()

  reaper.ImGui_SetNextWindowSize(ctx, 700, 520, reaper.ImGui_Cond_FirstUseEver())
  local visible, open = reaper.ImGui_Begin(ctx, "ChameleonDrummer", true)
  if visible then
    if font_sans then reaper.ImGui_PushFont(ctx, font_sans, FONT_SANS_SIZE) end

    if reaper.ImGui_BeginTabBar(ctx, "chameleon_tabs") then
      if reaper.ImGui_BeginTabItem(ctx, "Song Sections") then
        draw_song_sections_tab()
        reaper.ImGui_EndTabItem(ctx)
      end
      if reaper.ImGui_BeginTabItem(ctx, "Additive Rhythm") then
        draw_additive_rhythm_tab()
        reaper.ImGui_EndTabItem(ctx)
      end
      if reaper.ImGui_BeginTabItem(ctx, "Settings") then
        draw_settings_tab()
        reaper.ImGui_EndTabItem(ctx)
      end
      local log_tab_label = job_runner.is_running() and "Log *" or "Log"
      if reaper.ImGui_BeginTabItem(ctx, log_tab_label) then
        draw_log_tab()
        reaper.ImGui_EndTabItem(ctx)
      end
      reaper.ImGui_EndTabBar(ctx)
    end

    if font_sans then reaper.ImGui_PopFont(ctx) end
  end
  reaper.ImGui_End(ctx)

  if open then
    reaper.defer(loop)
  else
    reaper.ImGui_DestroyContext(ctx)
  end
end

-- Silent, non-prompting startup refresh
refresh_options()

reaper.defer(loop)
