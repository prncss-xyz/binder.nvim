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

function M.prepend(c)
  return function(keys, key)
    return keys .. c, key
  end
end

return M
