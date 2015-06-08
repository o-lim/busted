local s = require 'say'

return function(busted, loaders)
  local path = require 'pl.path'
  local dir = require 'pl.dir'
  local tablex = require 'pl.tablex'
  local shuffle = require 'busted.utils'.shuffle
  local file_loaders = {}

  for _, v in pairs(loaders) do
    local loader = require('busted.modules.files.'..v)
    file_loaders[#file_loaders+1] = loader
  end

  local function get_test_files(root_file, pattern, options)
    local file_list

    if path.isfile(root_file) then
      file_list = { root_file }
    elseif path.isdir(root_file) then
      local getfiles = options.recursive and dir.getallfiles or dir.getfiles
      file_list = getfiles(root_file)

      file_list = tablex.filter(file_list, function(filename)
        return path.basename(filename):find(pattern)
      end)

      file_list = tablex.filter(file_list, function(filename)
        if path.is_windows then
          return not filename:find('%\\%.%w+.%w+')
        else
          return not filename:find('/%.%w+.%w+')
        end
      end)
    else
      file_list = {}
    end

    return file_list
  end

  local function get_all_test_files(root_files, pattern, options)
    local file_list = {}
    for _, root in ipairs(root_files) do
      tablex.insertvalues(file_list, get_test_files(root, pattern, options))
    end
    return file_list
  end

  -- runs a testfile, loading its tests
  local function load_test_file(busted, filename)
    for _, v in pairs(file_loaders) do
      if v.match(busted, filename) then
        return v.load(busted, filename)
      end
    end
  end

  local function load_test_files(root_files, pattern, options)
    local file_list = get_all_test_files(root_files, pattern, options)

    if options.shuffle then
      shuffle(file_list, options.seed)
    elseif options.sort then
      table.sort(file_list)
    end

    for i, filename in ipairs(file_list) do
      local test_file, get_trace, rewrite_message = load_test_file(busted, filename)

      if test_file then
        local file = setmetatable({
          get_trace = get_trace,
          rewrite_message = rewrite_message
        }, {
          __call = test_file
        })

        busted.executors.file(filename, file)
      end
    end

    if #file_list == 0 then
      busted.publish({ 'error' }, {}, nil, s('output.no_test_files_match'):format(pattern), {})
    end

    return file_list
  end

  return load_test_files, load_test_file, get_all_test_files
end

