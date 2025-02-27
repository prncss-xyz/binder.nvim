local M = {}

function M.keymap_legendary(args)
  -- avoids displaying <nop> bindings in legendary popup
  if args.cb == '<nop>' then
    vim.keymap.set(args.modes, args.lhs, '<nop>', {})
  else
    if args.silent == nil then
      args.silent = true
    end
    require('legendary').keymap({
      args.lhs,
      args.cb,
      description = args.desc,
      opts = { expr = args.expr, silent = args.silent, remap = args.remap },
      mode = args.modes,
    })
  end
end

local _current_id = 0

local function next_id()
  _current_id = _current_id + 1
  return _current_id
end

function M.light_command_legendary(keymap_)
  local keymap = {
    string.format('<plug>(my-%d)', next_id()),
    keymap_[1],
    description = keymap_.desc,
  }
  require('legendary').keymap(keymap)
end

function M.prepend(c)
  return function(keys, key)
    return keys .. c, key
  end
end

return M
