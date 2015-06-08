-- Busted command-line runner

local path = require 'pl.path'
local term = require 'term'
local utils = require 'busted.utils'
local osexit = require 'busted.compatibility'.osexit
local loaded = false

return function(options)
  if loaded then return else loaded = true end

  local options = options or {}
  options.default_output = term.isatty(io.stdout) and 'utfTerminal' or 'plainTerminal'

  local busted = require 'busted.core'()

  local cli = require 'busted.modules.cli'(options)
  local filter_loader = require 'busted.modules.filter_loader'()
  local helper_loader = require 'busted.modules.helper_loader'()
  local output_handler_loader = require 'busted.modules.output_handler_loader'()

  local luacov = require 'busted.modules.luacov'()

  require 'busted'(busted)

  local level = 2
  local info = debug.getinfo(level, 'Sf')
  local source = info.source
  local filename = source:sub(1,1) == '@' and source:sub(2) or source

  -- Parse the cli arguments
  local app_name = path.basename(filename)
  cli:set_name(app_name)
  local cliargs, err = cli:parse(arg)
  if not cliargs then
    io.stderr:write(err .. '\n')
    osexit(1, true)
  end

  if cliargs.version then
    -- Return early if asked for the version
    print(busted.version)
    osexit(0, true)
  end

  -- Load current working directory
  local _, err = path.chdir(path.normpath(cliargs.directory))
  if err then
    io.stderr:write(app_name .. ': error: ' .. err .. '\n')
    osexit(1, true)
  end

  -- If coverage arg is passed in, load LuaCovsupport
  if cliargs.coverage then
    luacov()
  end

  -- If auto-insulate is disabled, re-register file without insulation
  if not cliargs['auto-insulate'] then
    busted.register('file', 'file', {})
  end

  -- If lazy is enabled, make lazy setup/teardown the default
  if cliargs.lazy then
    busted.register('setup', 'lazy_setup')
    busted.register('teardown', 'lazy_teardown')
  end

  -- Add additional package paths based on lpath and cpath cliargs
  if #cliargs.lpath > 0 then
    package.path = (cliargs.lpath .. ';' .. package.path):gsub(';;',';')
  end

  if #cliargs.cpath > 0 then
    package.cpath = (cliargs.cpath .. ';' .. package.cpath):gsub(';;',';')
  end

  -- watch for test errors and failures
  local failures = 0
  local errors = 0
  local quit_on_error = not cliargs['keep-going']

  busted.subscribe({ 'error', 'output' }, function(element, parent, message)
    io.stderr:write(app_name .. ': error: Cannot load output library: ' .. element.name .. '\n' .. message .. '\n')
    return nil, true
  end)

  busted.subscribe({ 'error', 'helper' }, function(element, parent, message)
    io.stderr:write(app_name .. ': error: Cannot load helper script: ' .. element.name .. '\n' .. message .. '\n')
    return nil, true
  end)

  busted.subscribe({ 'error' }, function(element, parent, message)
    errors = errors + 1
    busted.skip_all = quit_on_error
    return nil, true
  end)

  busted.subscribe({ 'failure' }, function(element, parent, message)
    if element.descriptor == 'it' then
      failures = failures + 1
    else
      errors = errors + 1
    end
    busted.skip_all = quit_on_error
    return nil, true
  end)

  -- Set up output handler to listen to events
  local output_handler_options = {
    verbose = cliargs.verbose,
    suppressPending = cliargs['suppress-pending'],
    language = cliargs.lang,
    deferPrint = cliargs['defer-print'],
    arguments = cliargs.Xoutput
  }

  local output_handler = output_handler_loader(busted, cliargs.output, output_handler_options, options.default_output)
  output_handler:subscribe(output_handler_options)

  if cliargs['enable-sound'] then
    require 'busted.outputHandlers.sound'(output_handler_options)
  end

  -- Set up randomization options
  busted.sort = cliargs['sort-tests']
  busted.randomize = cliargs['shuffle-tests']
  busted.randomseed = tonumber(cliargs.seed) or os.time()

  -- Set up tag and test filter options
  local filter_loader_options = {
    tags = cliargs.tags,
    exclude_tags = cliargs['exclude-tags'],
    filter = cliargs.filter,
    filter_out = cliargs['filter-out'],
    list = cliargs.list,
    nokeepgoing = not cliargs['keep-going'],
  }

  -- Load tag and test filters
  filter_loader(busted, filter_loader_options)

  -- Set up helper script
  if cliargs.helper and cliargs.helper ~= '' then
    local helper_options = {
      verbose = cliargs.verbose,
      language = cliargs.lang,
      arguments = cliargs.Xhelper
    }

    helper_loader(busted, cliargs.helper, helper_options)
  end

  -- Set up test loader options
  local test_file_loader_options = {
    verbose = cliargs.verbose,
    sort = cliargs['sort-files'],
    shuffle = cliargs['shuffle-files'],
    recursive = cliargs['recursive'],
    seed = busted.randomseed
  }

  -- Load test directory
  local root_files = cliargs.ROOT or { filename }
  local pattern = cliargs.pattern
  local test_file_loader = require 'busted.modules.test_file_loader'(busted, cliargs.loaders)
  test_file_loader(root_files, pattern, test_file_loader_options)

  -- If running standalone, setup test file to be compatible with live coding
  if not cliargs.ROOT then
    local ctx = busted.context.get()
    local children = busted.context.children(ctx)
    local file = children[#children]
    debug.getmetatable(file.run).__call = info.func
  end

  local runs = cliargs['repeat']
  local execute = require 'busted.execute'(busted)
  execute(runs, { seed = cliargs.seed })

  busted.publish({ 'exit' })

  local exit = 0
  if failures > 0 or errors > 0 then
    exit = failures + errors
    if exit > 255 then
      exit = 255
    end
  end
  osexit(exit, true)
end
