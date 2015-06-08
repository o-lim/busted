local path = require 'pl.path'

local ret = {}

local function get_trace(filename, info)
  local index = info.traceback:find('\n%s*%[C]')
  info.traceback = info.traceback:sub(1, index)
  return info, false
end

function ret.match(busted, filename)
  return path.extension(filename) == '.lua'
end


function ret.load(busted, filename)
  local file, err = loadfile(filename)
  if not file then
    busted.publish({ 'error', 'file' }, { descriptor = 'file', name = filename }, nil, err, {})
  end
  return file, get_trace
end

return ret
