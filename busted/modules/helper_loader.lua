local path = require 'pl.path'
local has_moon, moonscript = pcall(require, 'moonscript')

return function()
  local function load_helper(busted, helper, options)
    local old_arg = arg
    local success, err = pcall(function()
      arg = options.arguments
      if helper:match('%.lua$') then
        dofile(path.normpath(helper))
      elseif has_moon and helper:match('%.moon$') then
        moonscript.dofile(path.normpath(helper))
      else
        require(helper)
      end
    end)

    arg = old_arg

    if not success then
      busted.publish({ 'error', 'helper' }, { descriptor = 'helper', name = helper }, nil, err, {})
    end
  end

  return load_helper
end
