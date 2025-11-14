-- SCADA Computer Configuration

return {
  -- Factories
  -- List all factories and their LAN computer IDs
  factories = {
    {id = "iron", lan_id = 10},
    {id = "steel", lan_id = 20},
    {id = "copper", lan_id = 30}
  },
  
  -- UI settings
  monitor_peripheral = nil,        -- Monitor peripheral name, nil for terminal
  monitor_size = {
    width = 9,                     -- Monitor blocks wide
    height = 6                     -- Monitor blocks tall
  },
  
  ui_refresh_rate = 1,             -- Seconds between UI updates
  default_page = "dashboard",      -- "dashboard", "factory", "production", "alerts"
  
  -- Alert settings
  alert_sound = true,              -- Play sound on critical alerts
  alert_flash = true,              -- Flash screen on alerts
  alert_history_size = 100,        -- Number of alerts to keep in history
  
  -- Production calculation settings
  calculation_interval = 5,        -- Seconds between recalculating production/deficits
  deficit_threshold = -5,          -- IPM deficit threshold for warnings
  surplus_threshold = 50,          -- IPM surplus threshold for warnings
  
  -- Command settings
  command_timeout = 5000,          -- Milliseconds to wait for command acknowledgment
  command_retry_attempts = 3,      -- Number of retries for failed commands
  
  -- Factory monitoring
  factory_timeout = 15,            -- Seconds before considering factory offline
  
  -- Automatic control (optional)
  enable_auto_control = false,     -- Enable automatic production balancing
  auto_control_interval = 30,      -- Seconds between auto-control decisions
  
  -- Logging
  enable_logging = true,           -- Enable logging
  log_file = "scada.log",          -- Log file path
  log_calculations = false,        -- Log all deficit calculations (verbose)
  log_commands = true,             -- Log all sent commands
  log_alerts = true                -- Log all received alerts
}
