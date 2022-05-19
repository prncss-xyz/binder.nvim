local M = require('lua/binder/init')

local keys = M.keys
local b = M.b

local function f1() end

local bindings
local function create_bind_keymap_test(args)
  table.insert(bindings, args)
end

M.setup({
  dual_key = require('lua/binder/util').prepend('p'),
  bind_keymap = create_bind_keymap_test,
})

local function find_map(lhs, mode)
  for _, v in ipairs(bindings) do
    if v.lhs == lhs then
      for _, m in ipairs(v.modes) do
        -- this is because you can have multiple modes in one key, ef 'ox'
        if string.find(mode, m) then
          return vim.tbl_extend('force', v, { modes = { m } })
        else
        end
      end
    end
  end
end

describe('description', function()
  it('description', function()
    bindings = {}
    M.bind(keys({ x = b({ desc = 'desc1', f1 }) }))
    assert.are.same(
      { { lhs = 'x', cb = f1, desc = 'desc1', modes = { 'n' } } },
      bindings
    )
  end)
  it('concatenates', function()
    bindings = {}
    M.bind(
      keys({ desc = 'desc0', x = keys({ y = b({ desc = 'desc1', f1 }) }) })
    )
    assert.are.same(
      { { lhs = 'xy', cb = f1, desc = 'desc0 desc1', modes = { 'n' } } },
      bindings
    )
  end)
  it('respect prev', function()
    bindings = {}
    M.bind(keys({ prev = keys({ y = b({ desc = 'desc1', f1 }) }) }))
    assert.are.same(
      { { lhs = 'py', cb = f1, desc = 'previous desc1', modes = { 'n' } } },
      bindings
    )
  end)
  it('respect next', function()
    bindings = {}
    M.bind(keys({ next = keys({ y = b({ desc = 'desc1', f1 }) }) }))
    assert.are.same(
      { { lhs = 'y', cb = f1, desc = 'next desc1', modes = { 'n' } } },
      bindings
    )
  end)
  it('reduplicates', function()
    bindings = {}
    M.bind(keys({ x = keys({ redup = b({ desc = 'desc1', f1 }) }) }))
    assert.are.same(
      { { lhs = 'xx', cb = f1, desc = 'desc1', modes = { 'n' } } },
      bindings
    )
  end)
  it('command n', function()
    bindings = {}
    M.bind(keys({ x = b({ 'command1', cmd = true }) }))
    assert.are.same({
      { lhs = 'x', cb = ':command1<cr>', desc = 'command1', modes = { 'n' } },
    }, bindings)
  end)
  it('command o', function()
    bindings = {}
    M.bind(keys({ x = b({ 'command1', cmd = true, modes = 'o' }) }))
    assert.are.same({
      {
        lhs = 'x',
        cb = ':<c-u>command1<cr>',
        desc = 'command1',
        modes = { 'o' },
      },
    }, bindings)
  end)
  it('command nox', function()
    bindings = {}
    M.bind(keys({ x = b({ 'command1', cmd = true, modes = 'nox' }) }))
    assert.are.same({
      {
        lhs = 'x',
        cb = ':<c-u>command1<cr>',
        desc = 'command1',
        modes = { 'o' },
      },
      {
        lhs = 'x',
        cb = ':command1<cr>',
        desc = 'command1',
        modes = { 'n', 'x' },
      },
    }, bindings)
  end)
  it('command x', function()
    bindings = {}
    M.bind(keys({ x = b({ 'command1', cmd = true, modes = 'x' }) }))
    assert.are.same({
      { lhs = 'x', cb = ':command1<cr>', desc = 'command1', modes = { 'x' } },
    }, bindings)
  end)
  it('should respect modes', function()
    bindings = {}
    M.bind(M.modes({ o = keys({ x = b({ f1 }) }) }))
    assert.are.same({
      { lhs = 'x', cb = f1, modes = { 'o' } },
    }, bindings)
  end)
  it('should reuse state', function()
    bindings = {}
    M.bind(M.modes({ desc = 'test', o = keys({ register = 'label' }) }))
    M.extend('label', keys({ x = b({ f1 }) }))
    assert.are.same({
      { lhs = 'x', cb = f1, desc = 'test', modes = { 'o' } },
    }, bindings)
  end)

  it('should reuse state and add desc and key', function()
    bindings = {}
    M.bind(M.keys({ desc = 'test', x = keys({ register = 'label' }) }))
    M.with_labels('boo', 'u', {
      label = b({ f1 }),
    })
    assert.are.same({
      { lhs = 'xu', cb = f1, desc = 'test boo', modes = { 'n' } },
    }, bindings)
  end)
  it('should map complex stuff properly', function()
    bindings = {}
    M.bind(keys({
      desc = 'p',
      a = b({ 'A' }),
      b = b({ 'B' }),
      c = M.modes({
        desc = 'q',
        n = b({ 'C' }),
        o = keys({
          desc = 'r',
          d = b({ 'D' }),
          e = b({ 'E' }),
        }),
      }),
    }))
    assert.are.same({ lhs = 'a', cb = 'A', modes = { 'n' }, desc='p A' }, find_map('a', 'n'))
    assert.are.same({ lhs = 'b', cb = 'B', modes = { 'n' }, desc='p B' }, find_map('b', 'n'))
    assert.are.same({ lhs = 'c', cb = 'C', modes = { 'n' }, desc='p q C' }, find_map('c', 'n'))
    assert.are.same({ lhs = 'cd', cb = 'D', modes = { 'o' }, desc='p q r D' }, find_map('cd', 'o'))
    assert.are.same({ lhs = 'ce', cb = 'E', modes = { 'o' }, desc='p q r E' }, find_map('ce', 'o'))
  end)
end)
