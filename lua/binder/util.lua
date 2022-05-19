local M = {}

function M.bind_keymap_legendary(args)
  require('legendary').bind_keymap({
    args.lhs,
    args.cb,
    description = args.desc,
    mode = args.modes,
  })
end

function M.prepend(c)
  return function(keys, key)
    return keys .. c, key
  end
end

return M
