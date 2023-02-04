local M = {}

local conf
local reg = {}

function M.setup(opts)
  conf = opts
  conf.prefix = conf.prefix or ''
end

local function chars(str)
  local res = {}
  for char in string.gmatch(str, '.') do
    table.insert(res, char)
  end
  return res
end

local function reduce(acc, ...)
  local res = vim.tbl_extend('force', acc, ...)
  local desc = res.desc
  if not desc and type(res.default_desc) == 'string' then
    desc = res.default_desc
  end
  if desc then
    if res.descs then
      res.descs = res.descs .. ' ' .. desc
    else
      res.descs = desc
    end
    res.desc = nil
    res.default_desc = nil
  end
  if res.redesc then
    res.desc = res.redesc
  end
  return res
end

function M.b(args)
  return function(acc)
    local cb = args[1]
    assert(not vim.tbl_isempty(acc), 'is empty ' .. vim.inspect(acc))
    assert(
      not vim.tbl_isempty(args),
      'presenting an empty table to ' .. vim.inspect(acc)
    )
    acc = reduce(acc, args, { default_desc = cb })
    acc.keys = acc.keys .. acc.key
    if not acc.keys == '' then
      print('no LSH', dump(acc))
      return
    end
    if acc.modes ~= nil and type(acc.modes) ~= 'string' then
      assert(
        false,
        '`modes` is expected to be a string in ' .. vim.inspect(acc)
      )
      return
    end
    if acc.cmd then
      -- this is because you can have multiple modes in one key, ef 'ox'
      -- we still separate as few as we need because this causes mutliple rows in legendary
      local m = acc.modes
      local i = string.find(m, 'o')
      if i then
        conf.bind_keymap({
          lhs = acc.keys,
          cb = string.format(':<c-u>%s<cr>', cb),
          desc = acc.descs,
          expr = acc.expr,
          silent = acc.silent,
          remap = acc.remap,
          modes = { 'o' },
        })
        m = m:sub(1, i - 1) .. m:sub(i + 1, m:len())
      end
      if m ~= '' then
        conf.bind_keymap({
          lhs = acc.keys,
          cb = string.format(':%s<cr>', cb),
          desc = acc.descs,
          expr = acc.expr,
          silent = acc.silent,
          remap = acc.remap,
          modes = chars(m),
        })
      end
    else
      conf.bind_keymap({
        lhs = acc.keys,
        cb = cb,
        desc = acc.descs,
        expr = acc.expr,
        silent = acc.silent,
        remap = acc.remap,
        modes = chars(acc.modes),
      })
    end
  end
end

local function redup(keys, key)
  return keys .. key, key
end

function M.keys(args)
  return function(acc)
    local keys = acc.keys
    acc = reduce(acc, { desc = args.desc })

    for k, v in pairs(args) do
      if k == 'desc' then
      elseif k == 'register' then
        reg[v] = acc
      else
        if type(v) ~= 'function' and k ~= 'register' then
          print('key should be a function')
          dump(v)
        end
        if k == 'prev' then
          local keys_, key = conf.dual_key(keys, acc.key)
          keys_, key = v(vim.tbl_extend('force', acc, {
            keys = keys_,
            key = key,
            default_desc = 'previous',
          }))
        elseif k == 'next' then
          v(vim.tbl_extend('force', acc, { default_desc = 'next' }))
        elseif k == 'redup' then
          local keys_, key = redup(keys, acc.key)
          v(vim.tbl_extend('force', acc, { keys = keys_, key = key }))
        elseif type(k) == 'string' then
          v(vim.tbl_extend('force', acc, { keys = keys .. acc.key, key = k }))
        end
      end
    end
  end
end

function M.modes(args)
  return function(acc)
    acc = reduce(acc, { desc = args.desc })
    for k, v in pairs(args) do
      if k ~= 'desc' then
        if type(k) ~= 'string' then
          print('key should be a function')
          dump(acc)
          dump(k)
          dump(v)
        end
        if type(v) ~= 'function' then
          print('value should be a function')
          dump(acc)
          dump(k)
          dump(v)
        end
        v(vim.tbl_extend('force', acc, { modes = k }))
      end
    end
  end
end

function M.bind(cb)
  cb({ keys = '', key = '', modes = 'n' })
end

function M.extend(label, cb)
  local r = reg[label]
  if not r then
    print(string.format('label %q does not exists', label))
  else
    cb(reg[label])
  end
end

function M.with_labels(desc, key, args)
  for label, v in pairs(args) do
    local r = reg[label]
    if not r then
      print(string.format('label %q does not exists', label))
    else
      local acc = reduce(r, { desc = desc })
      acc.keys = acc.keys .. acc.key
      acc.key = key
      v(acc)
    end
  end
end

function M.extend_with(name)
  M.extend(name, require(conf.prefix .. name).extend(M))
end

return M
