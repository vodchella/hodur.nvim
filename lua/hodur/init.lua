local M = {}

local ns_id = vim.api.nvim_create_namespace('highlight_opened_line')

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
  local first = s:sub(1, 1)
  local last = s:sub(-1)

  if pairs[first] and pairs[first] == last then
    return s:sub(2, -2)
  end
  return s
end

local function is_separator(char)
  return not char or char:match("[%s%[%]{}()<>\'\"`]")
end

function M.open_under_cursor()
  local buf = vim.api.nvim_get_current_buf()
  local total_lines = vim.api.nvim_buf_line_count(buf)

  local pos = vim.api.nvim_win_get_cursor(0)
  local row = pos[1] - 1  -- 0-based строки
  local col = pos[2]      -- 0-based колонка

  local result = ""

  -- Сначала двигаемся влево
  do
    local cur_row = row
    local cur_col = col

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

      cur_row = cur_row - 1
      if cur_row >= 0 then
        line = vim.api.nvim_buf_get_lines(buf, cur_row, cur_row + 1, false)[1] or ""
        cur_col = #line - 1
        if line:match("^%s*$") then
          break
        end
      end
    end
  end

  -- Теперь двигаемся вправо
  do
    local cur_row = row
    local cur_col = col + 1

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

      cur_row = cur_row + 1
      cur_col = 0
      if cur_row < total_lines then
        line = vim.api.nvim_buf_get_lines(buf, cur_row, cur_row + 1, false)[1] or ""
        if line:match("^%s*$") then
          break
        end
      end
    end
  end

  -- Финальная обработка строки
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

  local expanded_path = vim.fn.expand(filepath)

  if filepath and vim.fn.filereadable(expanded_path) == 1 then
    vim.cmd.edit(vim.fn.fnameescape(expanded_path))
    vim.api.nvim_win_set_cursor(0, { tonumber(lineno), tonumber(colno) - 1 })

    -- Подсвечиваем строку в новом буфере
    local target_buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_clear_namespace(target_buf, ns_id, 0, -1)
    vim.api.nvim_buf_add_highlight(target_buf, ns_id, 'Visual', tonumber(lineno) - 1, 0, -1)
    vim.defer_fn(function()
      vim.api.nvim_buf_clear_namespace(target_buf, ns_id, 0, -1)
    end, 500)

  elseif filepath then
    vim.notify('File not found: ' .. expanded_path, vim.log.levels.WARN, { title = "Open Under Cursor" })
  else
    vim.notify('Cannot parse string', vim.log.levels.WARN, { title = "Open Under Cursor" })
  end
end

function M.setup(opts)
  opts = opts or {}
  local key = opts.key or "<C-g>"

  vim.keymap.set('n', key, M.open_under_cursor, { noremap = true, silent = true })
end

return M
