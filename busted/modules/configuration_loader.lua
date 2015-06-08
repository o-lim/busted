return function()
  local tablex = require 'pl.tablex'

  -- Function to load the .busted configuration file if available
  local function load_busted_configuration_file(config_file, config, defaults)
    if type(config_file) ~= 'table' then
      return config, '.busted file does not return a table.'
    end

    local defaults = defaults or {}
    local run = config.run or defaults.run

    if run and run ~= '' then
      local run_config = config_file[run]

      if type(run_config) == 'table' then
        config = tablex.merge(run_config, config, true)
      else
        return config, 'Task `' .. run .. '` not found, or not a table.'
      end
    elseif type(config_file.default) == 'table' then
      config = tablex.merge(config_file.default, config, true)
    end

    if type(config_file._all) == 'table' then
      config = tablex.merge(config_file._all, config, true)
    end

    config = tablex.merge(defaults, config, true)

    return config
  end

  return load_busted_configuration_file
end

