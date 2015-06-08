return function()
  local function filter(busted, options)
    local function get_full_name(name)
      local parent = busted.context.get()
      local names = { name }

      while parent and (parent.name or parent.descriptor) and
            parent.descriptor ~= 'file' do
        table.insert(names, 1, parent.name or parent.descriptor)
        parent = busted.context.parent(parent)
      end

      return table.concat(names, ' ')
    end

    local function has_tag(name, tag)
      local found = name:find('#' .. tag)
      return (found ~= nil)
    end

    local function filter_exclude_tags(name)
      for i, tag in pairs(options.exclude_tags) do
        if has_tag(name, tag) then
          return nil, false
        end
      end
      return nil, true
    end

    local function filter_tags(name)
      local fullname = get_full_name(name)
      for i, tag in pairs(options.tags) do
        if has_tag(fullname, tag) then
          return nil, true
        end
      end
      return nil, (#options.tags == 0)
    end

    local function filter_out_names(name)
      for _, filter in pairs(options.filter_out) do
        if get_full_name(name):find(filter) ~= nil then
          return nil, false
        end
      end
      return nil, true
    end

    local function filter_names(name)
      for _, filter in pairs(options.filter) do
        if get_full_name(name):find(filter) ~= nil then
          return nil, true
        end
      end
      return nil, (#options.filter == 0)
    end

    local function print_name_only(name, fn, trace)
      local fullname = get_full_name(name)
      if trace and trace.what == 'Lua' then
        print(trace.short_src .. ':' .. trace.currentline .. ': ' .. fullname)
      else
        print(fullname)
      end
      return nil, false
    end

    local function ignore_all()
      return nil, false
    end

    local function skip_on_error()
      return nil, not busted.skip_all
    end

    local function apply_filter(descriptors, name, fn)
      if options[name] and options[name] ~= '' then
        for _, descriptor in ipairs(descriptors) do
          busted.subscribe({ 'register', descriptor }, fn, { priority = 1 })
        end
      end
    end

    if options.list then
      busted.subscribe({ 'suite', 'start' }, ignore_all, { priority = 1 })
      busted.subscribe({ 'suite', 'end' }, ignore_all, { priority = 1 })
      apply_filter({ 'setup', 'teardown', 'before_each', 'after_each' }, 'list', ignore_all)
      apply_filter({ 'lazy_setup', 'lazy_teardown' }, 'list', ignore_all)
      apply_filter({ 'strict_setup', 'strict_teardown' }, 'list', ignore_all)
      apply_filter({ 'it', 'pending' }, 'list', print_name_only)
    end

    apply_filter({ 'lazy_setup', 'lazy_teardown' }, 'nokeepgoing', skip_on_error)
    apply_filter({ 'strict_setup', 'strict_teardown' }, 'nokeepgoing', skip_on_error)
    apply_filter({ 'setup', 'teardown', 'before_each', 'after_each' }, 'nokeepgoing', skip_on_error)
    apply_filter({ 'file', 'describe', 'it', 'pending' }, 'nokeepgoing', skip_on_error)

    -- The following filters are applied in reverse order
    apply_filter({ 'it', 'pending' }            , 'filter'      , filter_names       )
    apply_filter({ 'describe', 'it', 'pending' }, 'filter_out'  , filter_out_names   )
    apply_filter({ 'it', 'pending' }            , 'tags'        , filter_tags        )
    apply_filter({ 'describe', 'it', 'pending' }, 'exclude_tags', filter_exclude_tags)
  end

  return filter
end
