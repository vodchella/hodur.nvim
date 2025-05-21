local M = {}

local ns_id = vim.api.nvim_create_namespace('highlight_opened_line')
local notify_title = 'Hodur.nvim'

local function strip_wrapping_chars(s)
  local pairs = {
    ['"'] = '"',
    ["'"] = "'",
    ["("] = ")",
    ["["] = "]",
    ["{"] = "}",
    ["<"] = ">",
    ["`"] = "`",
  }
  while true do
    local first = s:sub(1, 1)
    local last = s:sub(-1)
    if pairs[first] and pairs[first] == last then
      s = s:sub(2, -2)
    else
      break
    end
  end
  return s
end

-- ':' НЕ разделитель!
local function is_separator(char)
  return not char or char:match("[%s%[%]{}()<>'\"`]")
end

local function should_continue_down(line)
  local last_char = line:sub(-1)
  return last_char == "." or last_char == ":"
end

local function is_url(str)
  if type(str) ~= "string" then return false end
  str = str:lower()
  return str:match("^https?://") or str:match("^ftp://")
end

local function highlight_text(row, start_col, end_col)
    local target_buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_clear_namespace(target_buf, ns_id, 0, -1)
    vim.api.nvim_buf_add_highlight(target_buf, ns_id, 'Visual', row, start_col, end_col)
    vim.defer_fn(function()
      vim.api.nvim_buf_clear_namespace(target_buf, ns_id, 0, -1)
    end, 500)
end

function M.open_under_cursor()
  local buf = vim.api.nvim_get_current_buf()
  local total_lines = vim.api.nvim_buf_line_count(buf)

  local pos = vim.api.nvim_win_get_cursor(0)
  local row = pos[1] - 1 -- 0-based строки
  local col = pos[2]     -- 0-based колонка

  local result = ""

  local cur_row = row
  local cur_col = col
  local last_col = col

  -- Идём влево
  do
    cur_row = row
    cur_col = col

    while cur_row >= 0 do
      local line = vim.api.nvim_buf_get_lines(buf, cur_row, cur_row + 1, false)[1] or ""

      while cur_col >= 0 do
        local c = line:sub(cur_col + 1, cur_col + 1)
        if is_separator(c) then
          break
        end
        result = c .. result
        cur_col = cur_col - 1
      end

      if cur_col >= 0 then
        break
      end

      -- Переход на строку выше
      cur_row = cur_row - 1
      if cur_row >= 0 then
        local prev_line = vim.api.nvim_buf_get_lines(buf, cur_row, cur_row + 1, false)[1] or ""
        if prev_line:match("^%s*$") then
          break
        end
        cur_col = #prev_line - 1
        if not should_continue_down(prev_line) then
          break
        end
      end
    end
  end

  -- Идём вправо
  do
    cur_row = row
    cur_col = col + 1

    while cur_row < total_lines do
      local line = vim.api.nvim_buf_get_lines(buf, cur_row, cur_row + 1, false)[1] or ""

      while cur_col < #line do
        local c = line:sub(cur_col + 1, cur_col + 1)
        if is_separator(c) then
          break
        end
        result = result .. c
        cur_col = cur_col + 1
      end

      if cur_col < #line then
        break
      end

      -- Переход на строку ниже
      cur_row = cur_row + 1
      last_col = cur_col
      cur_col = 0
      if cur_row < total_lines then
        local next_line = vim.api.nvim_buf_get_lines(buf, cur_row, cur_row + 1, false)[1] or ""
        if next_line:match("^%s*$") then
          break
        end
        local prev_line = vim.api.nvim_buf_get_lines(buf, cur_row - 1, cur_row, false)[1] or ""
        if not should_continue_down(prev_line) then
          break
        end
      end
    end
  end

  -- Обрезка кавычек и пробелов
  result = result:gsub("^%s+", ""):gsub("%s+$", "")
  result = strip_wrapping_chars(result)

  -- Парсим путь: файл[:строка[:колонка]]
  local filepath, lineno, colno
  filepath, lineno, colno = string.match(result, "([^:]+):(%d+):(%d+)")
  if not filepath then
    filepath, lineno = string.match(result, "([^:]+):(%d+)")
    colno = 1
  end
  if not filepath then
    filepath = result
    lineno = 1
    colno = 1
  end

  if is_url(filepath) then
    vim.fn.setreg('+', filepath)
    local len = vim.fn.strchars(filepath)
    if cur_col < 0 then
      start_col = last_col
      end_col = last_col + len
      cur_row = cur_row - 1
    elseif cur_col == 0 then
      start_col = last_col - len
      end_col = last_col
      cur_row = cur_row - 1
    else
      start_col = cur_col - len
      end_col = cur_col
    end
    vim.notify('URL copied to clipboard: ' .. filepath, vim.log.levels.INFO, { title = notify_title })
    highlight_text(cur_row, start_col, end_col)
    return
  end

  local expanded_path = vim.fn.expand(filepath)

  if filepath and vim.fn.filereadable(expanded_path) == 1 then
    vim.cmd.edit(vim.fn.fnameescape(expanded_path))
    vim.api.nvim_win_set_cursor(0, { tonumber(lineno), tonumber(colno) - 1 })

    -- Подсветка строки
    highlight_text(tonumber(lineno) - 1, 0, -1)

  elseif filepath then
    vim.notify('File not found: ' .. expanded_path, vim.log.levels.WARN, { title = notify_title })
  else
    vim.notify('Cannot parse string', vim.log.levels.WARN, { title = notify_title })
  end
end

function M.setup(opts)
  opts = opts or {}
  local key = opts.key or "<C-g>"

  vim.keymap.set('n', key, M.open_under_cursor, { noremap = true, silent = true })
end

return M
