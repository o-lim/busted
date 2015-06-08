local utils = require 'busted.utils'
local path = require 'pl.path'
local tablex = require 'pl.tablex'

return function(options)
  local app_name = ''
  local options = options or {}
  local cli = require 'cliargs'

  local config_loader = require 'busted.modules.configuration_loader'()

  -- Default cli arg values
  local default_output = options.default_output
  local default_loaders = 'lua,moonscript'
  local default_pattern = '_spec'
  local default_seed = 'os.time()'
  local lpathprefix = './src/?.lua;./src/?/?.lua;./src/?/init.lua'
  local cpathprefix = path.is_windows and './csrc/?.dll;./csrc/?/?.dll;' or './csrc/?.so;./csrc/?/?.so;'

  local cliparsed = {}

  local function fixup_list(values, sep)
    local sep = sep or ','
    local list = type(values) == 'table' and values or { values }
    local olist = {}
    for _, v in ipairs(list) do
      tablex.insertvalues(olist, utils.split(v, sep))
    end
    return olist
  end

  local function process_option(key, value, altkey, opt)
    if altkey then cliparsed[altkey] = value end
    cliparsed[key] = value
    return true
  end

  local function process_arg(key, value)
    cliparsed[key] = value
    return true
  end

  local function process_arg_list(key, value)
    local list = cliparsed[key] or {}
    tablex.insertvalues(list, utils.split(value, ','))
    process_arg(key, list)
    return true
  end

  local function process_number(key, value, altkey, opt)
    local number = tonumber(value)
    if not number then
      return nil, 'argument to ' .. opt:gsub('=.*', '') .. ' must be a number'
    end
    if altkey then cliparsed[altkey] = number end
    cliparsed[key] = number
    return true
  end

  local function process_list(key, value, altkey, opt)
    local list = cliparsed[key] or {}
    tablex.insertvalues(list, utils.split(value, ','))
    process_option(key, list, altkey, opt)
    return true
  end

  local function process_multi_option(key, value, altkey, opt)
    local list = cliparsed[key] or {}
    table.insert(list, value)
    process_option(key, list, altkey, opt)
    return true
  end

  local function append(s1, s2, sep)
    local sep = sep or ''
    if not s1 then return s2 end
    return s1 .. sep .. s2
  end

  local function process_loaders(key, value, altkey, opt)
    local loaders = append(cliparsed[key], value, ',')
    process_option(key, loaders, altkey, opt)
    return true
  end

  local function process_path(key, value, altkey, opt)
    local lpath = append(cliparsed[key], value, ';')
    process_option(key, lpath, altkey, opt)
    return true
  end

  local function process_dir(key, value, altkey, opt)
    local dpath = path.join(cliparsed[key] or '', value)
    process_option(key, dpath, altkey, opt)
    return true
  end

  local function process_shuffle(key, value, altkey, opt)
    process_option('shuffle-files', value, nil, opt)
    process_option('shuffle-tests', value, nil, opt)
  end

  local function process_sort(key, value, altkey, opt)
    process_option('sort-files', value, nil, opt)
    process_option('sort-tests', value, nil, opt)
  end

  -- Load up the command-line interface options
  cli:add_flag('--version', 'prints the program version and exits', false, process_option)

  if options.batch then
    cli:optarg('ROOT', 'test script file/folder. Folders will be traversed for any file that matches the --pattern option.', 'spec', 999, process_arg_list)

    cli:add_option('-p, --pattern=PATTERN', 'only run test files matching the Lua pattern', default_pattern, process_option)
  end

  cli:add_option('-o, --output=LIBRARY', 'output library to load', default_output, process_option)
  cli:add_option('-C, --directory=DIR', 'change to directory DIR before running tests. If multiple options are specified, each is interpreted relative to the previous one.', './', process_dir)
  cli:add_option('-f, --config-file=FILE', 'load configuration options from FILE', nil, process_option)
  cli:add_option('-t, --tags=TAGS', 'only run tests with these #tags', {}, process_list)
  cli:add_option('--exclude-tags=TAGS', 'do not run tests with these #tags, takes precedence over --tags', {}, process_list)
  cli:add_option('--filter=PATTERN', 'only run test names matching the Lua pattern', {}, process_multi_option)
  cli:add_option('--filter-out=PATTERN', 'do not run test names matching the Lua pattern, takes precedence over --filter', {}, process_multi_option)
  cli:add_option('-m, --lpath=PATH', 'optional path to be prefixed to the Lua module search path', lpathprefix, process_path)
  cli:add_option('--cpath=PATH', 'optional path to be prefixed to the Lua C module search path', cpathprefix, process_path)
  cli:add_option('-r, --run=RUN', 'config to run from .busted file', nil, process_option)
  cli:add_option('--repeat=COUNT', 'run the tests repeatedly', '1', process_number)
  cli:add_option('--seed=SEED', 'random seed value to use for shuffling test order', default_seed, process_number)
  cli:add_option('--lang=LANG', 'language for error messages', 'en', process_option)
  cli:add_option('--loaders=NAME', 'test file loaders', default_loaders, process_loaders)
  cli:add_option('--helper=PATH', 'A helper script that is run before tests', nil, process_option)

  cli:add_option('-Xoutput OPTION', 'pass `OPTION` as an option to the output handler. If `OPTION` contains commas, it is split into multiple options at the commas.', {}, process_list)
  cli:add_option('-Xhelper OPTION', 'pass `OPTION` as an option to the helper script. If `OPTION` contains commas, it is split into multiple options at the commas.', {}, process_list)

  cli:add_flag('-c, --[no-]coverage', 'do code coverage analysis (requires `LuaCov` to be installed)', false, process_option)
  cli:add_flag('-v, --[no-]verbose', 'verbose output of errors', false, process_option)
  cli:add_flag('-s, --[no-]enable-sound', 'executes `say` command if available', false, process_option)
  cli:add_flag('-l, --list', 'list the names of all tests instead of running them', false, process_option)
  cli:add_flag('--[no-]lazy', 'use lazy setup/teardown as the default', false, process_option)
  cli:add_flag('--[no-]auto-insulate', 'enable file insulation', true, process_option)
  cli:add_flag('-k, --[no-]keep-going', 'continue as much as possible after an error or failure', true, process_option)
  cli:add_flag('-R, --[no-]recursive', 'recurse into subdirectories', true, process_option)
  cli:add_flag('--[no-]shuffle', 'randomize file and test order, takes precedence over --sort (--shuffle-test and --shuffle-files)', process_shuffle)
  cli:add_flag('--[no-]shuffle-files', 'randomize file execution order, takes precedence over --sort-files', process_option)
  cli:add_flag('--[no-]shuffle-tests', 'randomize test order within a file, takes precedence over --sort-tests', process_option)
  cli:add_flag('--[no-]sort', 'sort file and test order (--sort-tests and --sort-files)', process_sort)
  cli:add_flag('--[no-]sort-files', 'sort file execution order', process_option)
  cli:add_flag('--[no-]sort-tests', 'sort test order within a file', process_option)
  cli:add_flag('--[no-]suppress-pending', 'suppress `pending` test output', false, process_option)
  cli:add_flag('--[no-]defer-print', 'defer print to when test suite is complete', false, process_option)

  local function parse(args)
    -- Parse the cli arguments
    local cliargs, clierr = cli:parse(args, true)
    if not cliargs then
      return nil, clierr
    end

    -- Load busted config file if available
    local config_file = { }
    local busted_config_file_path = cliargs.f or path.normpath(path.join(cliargs.directory, '.busted'))
    local busted_config_file = pcall(function() config_file = loadfile(busted_config_file_path)() end)
    if busted_config_file then
      local config, err = config_loader(config_file, cliparsed, cliargs)
      if err then
        return nil, app_name .. ': error: ' .. err
      else
        cliargs = config
      end
    else
      cliargs = tablex.merge(cliargs, cliparsed, true)
    end

    -- Fixup options in case options from config file are not of the right form
    cliargs.tags = fixup_list(cliargs.tags)
    cliargs.t = cliargs.tags
    cliargs['exclude-tags'] = fixup_list(cliargs['exclude-tags'])
    cliargs.loaders = fixup_list(cliargs.loaders)
    cliargs.Xoutput = fixup_list(cliargs.Xoutput)
    cliargs.Xhelper = fixup_list(cliargs.Xhelper)

    -- We report an error if the same tag appears in both `options.tags`
    -- and `options.excluded_tags` because it does not make sense for the
    -- user to tell Busted to include and exclude the same tests at the
    -- same time.
    for _, excluded in pairs(cliargs['exclude-tags']) do
      for _, included in pairs(cliargs.tags) do
        if excluded == included then
          return nil, app_name .. ': error: Cannot use --tags and --exclude-tags for the same tags'
        end
      end
    end

    cliargs['repeat'] = tonumber(cliargs['repeat'])

    return cliargs
  end

  return {
    set_name = function(self, name)
      app_name = name
      return cli:set_name(name)
    end,

    parse = function(self, args)
      return parse(args)
    end
  }
end
