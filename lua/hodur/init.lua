local M = {}

function M.open_under_cursor()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.fn.getline('.')

  local start_col = col
  local end_col = col

  local function is_separator(char)
    return char == nil or char:match("[%s]")
  end

  while start_col > 0 and not is_separator(line:sub(start_col, start_col)) do
    start_col = start_col - 1
  end
  if start_col ~= col then
    start_col = start_col + 1
  end

  while end_col < #line and not is_separator(line:sub(end_col + 1, end_col + 1)) do
    end_col = end_col + 1
  end

  local target = line:sub(start_col, end_col)
  target = target:gsub("^%s+", ""):gsub("%s+$", "")

  local filepath, lineno, colno
  filepath, lineno, colno = string.match(target, "([^:]+):(%d+):(%d+)")
  if not filepath then
    filepath, lineno = string.match(target, "([^:]+):(%d+)")
    colno = 1
  end
  if not filepath then
    filepath = target
    lineno = 1
    colno = 1
  end

  if filepath then
    if vim.fn.filereadable(filepath) == 1 then
      vim.cmd('edit ' .. vim.fn.fnameescape(filepath))
      vim.api.nvim_win_set_cursor(0, { tonumber(lineno), tonumber(colno) - 1 })

      local ns_id = vim.api.nvim_create_namespace('highlight_opened_line')
      local buf = vim.api.nvim_get_current_buf()
      local line_num = tonumber(lineno) - 1
      vim.api.nvim_buf_add_highlight(buf, ns_id, 'Visual', line_num, 0, -1)
      vim.defer_fn(function()
        vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
      end, 500)

    else
      vim.notify('File not found: ' .. filepath, vim.log.levels.WARN)
    end
  else
    vim.notify('Can not parse string', vim.log.levels.WARN)
  end
end

function M.setup(opts)
  opts = opts or {}
  local key = opts.key or "<C-g>"

  vim.keymap.set('n', key, M.open_under_cursor, { noremap = true, silent = true })
end

return M
