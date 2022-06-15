local M = {}

function M.bind_keymap_legendary(args)
  -- avoids displaying <nop> bindings in legendary popup
  if args.cb == '<nop>' then
    vim.keymap.set(args.modes, args.lhs, '<nop>', {})
  else
    require('legendary').bind_keymap({
      args.lhs,
      args.cb,
      description = args.desc,
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
  require('legendary').bind_keymap(keymap)
end

function M.prepend(c)
  return function(keys, key)
    return keys .. c, key
  end
end

return M
