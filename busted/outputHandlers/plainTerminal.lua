local s = require 'say'
local pretty = require 'pl.pretty'

return function(options)
  local busted = require 'busted'
  local handler = require 'busted.outputHandlers.base'()

  local successDot =  '+'
  local failureDot =  '-'
  local errorDot =  '*'
  local pendingDot = '.'

  local function pending_description(pending)
    local name = pending.name

    local string = s('output.pending') .. ' -> ' ..
      pending.trace.short_src .. ' @ ' ..
      pending.trace.currentline  ..
      '\n' .. name

    if type(pending.message) == 'string' then
      string = string .. '\n' .. pending.message
    elseif pending.message ~= nil then
      string = string .. '\n' .. pretty.write(pending.message)
    end

    return string
  end

  local function failure_message(failure)
    local string = failure.randomseed and ('Random seed: ' .. failure.randomseed .. '\n') or ''
    if type(failure.message) == 'string' then
      string = string .. failure.message
    elseif failure.message == nil then
      string = string .. 'Nil error'
    else
      string = string .. pretty.write(failure.message)
    end

    return string
  end

  local function failure_description(failure, isError)
    local string = s('output.failure') .. ' -> '
    if isError then
      string = s('output.error') .. ' -> '
    end

    if not failure.element.trace or not failure.element.trace.short_src then
      string = string ..
        failure_message(failure) .. '\n' ..
        failure.name
    else
      string = string ..
        failure.element.trace.short_src .. ' @ ' ..
        failure.element.trace.currentline .. '\n' ..
        failure.name .. '\n' ..
        failure_message(failure)
    end

    if options.verbose and failure.trace and failure.trace.traceback then
      string = string .. '\n' .. failure.trace.traceback
    end

    return string
  end

  local status_string = function()
    local success_string = s('output.success_plural')
    local failure_string = s('output.failure_plural')
    local pending_string = s('output.pending_plural')
    local error_string = s('output.error_plural')

    local ms = handler.getDuration()
    local successes = handler.successesCount
    local pendings = handler.pendingsCount
    local failures = handler.failuresCount
    local errors = handler.errorsCount

    if successes == 0 then
      success_string = s('output.success_zero')
    elseif successes == 1 then
      success_string = s('output.success_single')
    end

    if failures == 0 then
      failure_string = s('output.failure_zero')
    elseif failures == 1 then
      failure_string = s('output.failure_single')
    end

    if pendings == 0 then
      pending_string = s('output.pending_zero')
    elseif pendings == 1 then
      pending_string = s('output.pending_single')
    end

    if errors == 0 then
      error_string = s('output.error_zero')
    elseif errors == 1 then
      error_string = s('output.error_single')
    end

    local formattedTime = ('%.6f'):format(ms):gsub('([0-9])0+$', '%1')

    return successes .. ' ' .. success_string .. ' / ' ..
      failures .. ' ' .. failure_string .. ' / ' ..
      errors .. ' ' .. error_string .. ' / ' ..
      pendings .. ' ' .. pending_string .. ' : ' ..
      formattedTime .. ' ' .. s('output.seconds')
  end

  handler.testEnd = function(element, parent, status, debug)
    if not options.defer_print then
      local string = successDot

      if status == 'pending' then
        string = pendingDot
      elseif status == 'failure' then
        string = failureDot
      elseif status == 'error' then
        string = errorDot
      end

      io.write(string)
      io.flush()
    end

    return nil, true
  end

  handler.suiteStart = function(suite, count, total)
    local runString = (total > 1 and '\nRepeating all tests (run %d of %d) . . .\n\n' or '')
    io.write(runString:format(count, total))
    io.flush()

    return nil, true
  end

  handler.suiteEnd = function()
    print('')
    print(status_string())

    for i, pending in pairs(handler.pendings) do
      print('')
      print(pending_description(pending))
    end

    for i, err in pairs(handler.failures) do
      print('')
      print(failure_description(err))
    end

    for i, err in pairs(handler.errors) do
      print('')
      print(failure_description(err, true))
    end

    return nil, true
  end

  handler.error = function(element, parent, message, debug)
    io.write(errorDot)
    io.flush()

    return nil, true
  end

  busted.subscribe({ 'test', 'end' }, handler.testEnd, { predicate = handler.cancelOnPending })
  busted.subscribe({ 'suite', 'start' }, handler.suiteStart)
  busted.subscribe({ 'suite', 'end' }, handler.suiteEnd)
  busted.subscribe({ 'error', 'file' }, handler.error)
  busted.subscribe({ 'failure', 'file' }, handler.error)
  busted.subscribe({ 'error', 'describe' }, handler.error)
  busted.subscribe({ 'failure', 'describe' }, handler.error)

  return handler
end
