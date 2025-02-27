local M = {}

function M.plug(str)
  return '<plug>(' .. str .. ')'
end

function M.cmd(str)
  return '<cmd>' .. str .. '<cr>'
end

function M.lua(str)
  return '<cmd>lua ' .. str .. '<cr>'
end

function M.cmd_partial(str)
  return '<cmd>' .. str .. '<cr>'
end

return M
