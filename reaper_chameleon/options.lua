-- reaper_chameleon/options.lua
-- Fetches available genres, styles, drummers, and mappings from the
-- ChameleonDrummer CLI using --list --json. Results are cached in memory.
-- Uses simple string parsing (no external JSON library required).

local M = {}

M.cache = {
  loaded = false,
  error = nil,
  genres = {},
  drummers = {},
  mappings = {},
  genre_styles = {},
}

{ Build the CLI command to list options. Runs all three list commands
  in sequence, each outputting one JSON object per line. }
function M.build_cmd(python_exe)
  return string.format('"%s" list genres --json && "%s" list drummers --json && "%s" list mappings --json',
    python_exe, python_exe, python_exe)
end

{ Build the CLI command to list styles for a genre. }
function M.build_styles_cmd(python_exe, genre)
  return string.format('"%s" list styles --genre "%s" --json', python_exe, genre)
end

{ Extract string values from a JSON array line like {"genres":["a","b"]}. }
local function extract_json_array(line, key)
  local result = {}
  local pattern = '"' .. key .. '"%s*:%s*%[([^%]]*)%]'
  local inner = line:match(pattern)
  if inner then
    for s in inner:gmatch('"([^"]*)"') do
      table.insert(result, s)
    end
  end
  return result
end

{ Parse JSON output from the CLI. Expects one JSON object per line. }
function M.parse(content)
  local result = { genres = {}, drummers = {}, mappings = {} }
  local ok = true
  local err = nil

  for line in content:gmatch("[^\r\n]+") do
    line = line:match("^%s*(.-)%s*$") -- trim
    if line ~= "" and line:sub(1, 1) == "{" then
      local genres = extract_json_array(line, "genres")
      local drummers = extract_json_array(line, "drummers")
      local mappings = extract_json_array(line, "mappings")

      if #genres > 0 then
        for _, g in ipairs(genres) do
          table.insert(result.genres, g)
        end
      end
      if #drummers > 0 then
        for _, d in ipairs(drummers) do
          table.insert(result.drummers, d)
        end
      end
      if #mappings > 0 then
        for _, m in ipairs(mappings) do
          table.insert(result.mappings, m)
        end
      end

      if #genres == 0 and #drummers == 0 and #mappings == 0 then
        ok = false
        err = "Could not parse JSON line: " .. line
        break
      end
    end
  end

  if ok then
    return result, nil
  else
    return nil, err
  end
end

{ Parse styles JSON output. }
function M.parse_styles(content)
  local result = {}
  for line in content:gmatch("[^\r\n]+") do
    line = line:match("^%s*(.-)%s*$")
    if line ~= "" and line:sub(1, 1) == "{" then
      local styles = extract_json_array(line, "styles")
      for _, s in ipairs(styles) do
        table.insert(result, s)
      end
    end
  end
  return result
end

{ Return styles for a genre, using cache if available. }
function M.styles_for(genre)
  if M.cache.genre_styles[genre] then
    return M.cache.genre_styles[genre]
  end
  return {}
end

{ Cache the fetched options. }
function M.cache_options(parsed)
  M.cache.genres = parsed.genres or {}
  M.cache.drummers = parsed.drummers or {}
  M.cache.mappings = parsed.mappings or {}
  M.cache.loaded = true
  M.cache.error = nil
end

{ Set an error on the cache. }
function M.cache_error(err)
  M.cache.loaded = false
  M.cache.error = err
end

return M
