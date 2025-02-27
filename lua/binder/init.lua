local M = {}

-- TODO: inline cb

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

local function lazy_req(module, fn_path, ...)
  local args = { ... }
  return function()
    local path = vim.split(fn_path, '.', { plain = true })
    local fn = require(module)
    for _, p in ipairs(path) do
      fn = fn[p]
    end
    return fn(unpack(args))
  end
end

local function register(obj)
  if obj.cmd == 'np' then
  end
  local deserialize = M.deserialize[obj.cmd]
  if deserialize then
    obj.cb = deserialize(obj.cb)
  end
  if obj.cmd == 'np' then
  end
  conf.bind_keymap(obj)
end

M.register = {}
M.deserialize = {}

local function cmd_split(t)
  local t1, t2
  for _, v in ipairs(t) do
    if v == 'o' then
      t2 = { 'o' }
    else
      t1 = t1 or {}
      table.insert(t1, v)
    end
  end
  return t1 or false, t2 or false
end

function M.register.cmd(call, name)
  call.cmd = 'keys'
  -- this is because you can have multiple modes in one key, eg 'ox'
  -- we still separate as few as we need because this causes mutliple rows in legendary
  local modes, modes_o = cmd_split(call.modes)
  local call_
  if modes then
    call_ = vim.tbl_extend(
      'force',
      call,
      { modes = modes, cb = string.format(':%s<cr>', name) }
    )
  end
  if modes_o then
    call.modes = modes_o
    call.cb = string.format(':<c-u>%s<cr>', name)
    return call, call_
  else
    return call
  end
end

local function seralize_req(module, fn_path, ...)
  return {
    module = module,
    fn_path = fn_path,
    ...,
  }
end

function M.register.req(call, ...)
  call.cmd = 'req'
  call.cb = seralize_req(...)
  return call
end

function M.deserialize.req(obj)
  return function()
    local path = vim.split(obj.fn_path, '.', { plain = true })
    local fn = require(obj.module)
    for _, p in ipairs(path) do
      fn = fn[p]
    end
    return fn(unpack(obj))
  end
end

local function seralize_vim(fn_path, ...)
  return {
    fn_path = fn_path,
    ...,
  }
end

function M.register.vim(call, ...)
  call.cmd = 'vim'
  call.cb = seralize_vim(...)
  return call
end

function M.deserialize.vim(obj)
  return function()
    local path = vim.split(obj.fn_path, '.', { plain = true })
    local fn = vim
    for _, p in ipairs(path) do
      fn = fn[p]
    end
    return fn(unpack(obj))
  end
end

function M.register.keys(call, rhs)
  call.cmd = 'keys'
  call.cb = rhs
  return call
end

function M.deserialize.np(obj)
  return function()
    local prev = function()
      M.deserialize[obj.prev.cmd](obj.prev.cb)()
    end
    local next = function()
      M.deserialize[obj.next.cmd](obj.next.cb)()
    end
    require('flies.actions.move_again').register(prev, next)
    if obj.fwd then
      next()
    else
      prev()
    end
  end
end

function M.register.np(call, prev, next_, fwd)
  prev = vim.deepcopy(prev)
  local cmd = table.remove(prev, 1)
  local cp = { cmd = cmd }
  prev = M.register[cmd](cp, unpack(prev))

  next_ = vim.deepcopy(next_)
  cmd = table.remove(next_, 1)
  local cn = { cmd = cmd }
  next_ = M.register[cmd](cn, unpack(next_))

  local cb = {
    prev = prev,
    next = next_,
    fwd = fwd,
  }

  return vim.tbl_extend('force', call, {
    cmd = 'np',
    cb = cb,
  })
end

function M.b(args)
  local command = args[1]
  if not command then
    return
  end
  if M.register[command] then
    table.remove(args, 1)
  else
    -- TODO: temporary
    if args.cmd then
      command = 'cmd'
    else
      command = 'keys'
    end
  end
  return function(acc)
    local default_desc = type(args[1]) == 'string' and args[1]
    acc = reduce(acc, args, { default_desc = default_desc })
    acc.keys = acc.keys .. acc.key
    if not acc.keys == '' then
      print('no LHS', vim.inspect(acc))
      return
    end
    if acc.modes ~= nil and type(acc.modes) ~= 'string' then
      assert(
        false,
        '`modes` is expected to be a string in ' .. vim.inspect(acc)
      )
      return
    end

    local call = {
      lhs = acc.keys,
      modes = acc.modes and chars(acc.modes) or { 'n' },
      desc = acc.descs,
      expr = acc.expr,
      silent = acc.silent,
      remap = acc.remap,
    }
    local c1, c2 = M.register[command](call, unpack(acc))
    if c1 then
      register(c1)
    end
    if c2 then
      register(c2)
    end
  end
end

function M.b__(args)
  return function(acc)
    local cb = args[1]
    assert(not vim.tbl_isempty(acc), 'is empty ' .. vim.inspect(acc))
    assert(
      not vim.tbl_isempty(args),
      'presenting an empty table to ' .. vim.inspect(acc)
    )
    if args[1] == 'keys' then
      cb = args[2]
    elseif args[1] == 'req' then
      table.remove(args, 1)
      cb = lazy_req(unpack(args))
    elseif args[1] == 'cmd' then
      cb = args[2]
      acc.cmd = true
    end
    acc = reduce(acc, args, { default_desc = cb })
    acc.keys = acc.keys .. acc.key
    if not acc.keys == '' then
      print('no LHS', vim.inspect(acc))
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
      local index = string.find(m, 'o')
      if index then
        conf.bind_keymap({
          lhs = acc.keys,
          cb = string.format(':<c-u>%s<cr>', cb),
          desc = acc.descs,
          expr = acc.expr,
          silent = acc.silent,
          remap = acc.remap,
          modes = { 'o' },
        })
        m = m:sub(1, index - 1) .. m:sub(index + 1, m:len())
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
          print(vim.inspect(v))
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
          print(vim.inspect(acc))
          print(vim.inspect(k))
          print(vim.inspect(v))
        end
        if type(v) ~= 'function' then
          print('value should be a function')
          print(vim.inspect(acc))
          print(vim.inspect(k))
          print(vim.inspect(v))
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
