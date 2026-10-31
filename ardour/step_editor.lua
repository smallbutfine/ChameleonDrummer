-- reaper_chameleon/step_editor.lua
-- Step Editor tab logic: load MIDI item, edit grid, apply drummer.

local M = {}

function M.get_selected_media_item()
  local item = reaper.GetSelectedMediaItem(0, 0)
  return item
end

function M.load_midi_item(midi_path)
  if midi_path and midi_path ~= "" then
    reaper.InsertMedia(midi_path, 0)
    reaper.UpdateArrange()
    return true
  end
  return false
end

-- Build CLI command to generate a pattern with drummer styling
function M.build_apply_drummer_cmd(exe, midi_path, output_json, drummer, intensity, timing_variance, velocity_variance)
  local drummer_flag = ""
  if drummer and drummer ~= "" then
    drummer_flag = string.format(' --drummer "%s"', drummer)
  end
  local intensity_flag = string.format(' --drummer-intensity %g', intensity or 1.0)
  local timing_flag = string.format(' --timing-variance %g', timing_variance or 0.0)
  local velocity_flag = string.format(' --velocity-variance %g', velocity_variance or 0.0)
  
  return string.format(
    '"%s" generate --drummer "%s" --drummer-intensity %g --timing-variance %g --velocity-variance %g --output "%s"',
    exe, drummer, intensity, timing_variance, velocity_variance, output_json
  )
end

function M.parse_grid_steps(grid_text)
  local steps = {}
  for char in grid_text:gmatch(".") do
    if char == "x" or char == "X" or char == "." or char == " " then
      steps[#steps + 1] = char
    end
  end
  return steps
end

function M.build_step_pattern(grid_string, instrument_map)
  local pattern = {}
  for i = 1, #grid_string do
    local char = grid_string:sub(i, i)
    if char == "x" or char == "X" then
      pattern[i] = { instrument = instrument_map or "K", velocity = 100, accent = (char == "X") }
    elseif char == "." then
      pattern[i] = { instrument = instrument_map or "K", velocity = 0, ghost = true }
    else
      pattern[i] = nil
    end
  end
  return pattern
end

return M