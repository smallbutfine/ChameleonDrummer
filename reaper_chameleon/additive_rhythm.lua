-- reaper_chameleon/additive_rhythm.lua
-- Additive Rhythm tab logic for the ChameleonDrummer REAPER panel.
-- Converts box notation grouping strings into drum patterns.

local M = {}

{ Build the additive-rhythm CLI command. }
function M.build_cmd(exe, grouping, grid, tempo, mapping, midi_out, drummer, intensity, write_timeline, timeline_path)
  local drummer_flag = ""
  if drummer and drummer ~= "" then
    drummer_flag = string.format(' --drummer "%s" --drummer-intensity %g', drummer, intensity)
  end
  local timeline_flag = ""
  if write_timeline and timeline_path and timeline_path ~= "" then
    timeline_flag = string.format(' --write-timeline "%s"', timeline_path)
  end
  return string.format(
    '"%s" additive-rhythm --grouping "%s" --grid %s --tempo %s --mapping "%s" --output "%s"%s%s',
    exe, grouping, grid, tempo, mapping, midi_out, drummer_flag, timeline_flag
  )
end

{ Parse timeline JSON output into tempo_points array. }
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
  return tempo_points
end

return M
