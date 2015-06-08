local path = require 'pl.path'
local has_moon, moonscript = pcall(require, 'moonscript')

return function()
  local function load_output_handler(busted, output, options, default_output)
    local handler

    local success, err = pcall(function()
      if output:match('%.lua$') then
        handler = dofile(path.normpath(output))
      elseif has_moon and output:match('%.moon$') then
        handler = moonscript.dofile(path.normpath(output))
      else
        handler = require('busted.outputHandlers.' .. output)
      end
    end)

    if not success and err:match("module '.-' not found:") then
      success, err = pcall(function() handler = require(output) end)
    end

    if not success then
      busted.publish({ 'error', 'output' }, { descriptor = 'output', name = output }, nil, err, {})
      handler = require('busted.outputHandlers.' .. default_output)
    end

    return handler(options)
  end

  return load_output_handler
end
