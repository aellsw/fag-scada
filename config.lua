-- SCADA Computer Configuration

return {
  -- List all factories and their LAN computer IDs
  factories = {
    {id = "test", lan_id = 1},
    {id = "testing", lan_id = 10},
  },
  
  -- UI settings
  monitor_peripheral = nil, -- Monitor peripheral name, nil for terminal
  monitor_size = {
    width = 9,
    height = 6
  },
  
  ui_refresh_rate = 1,
  default_page = "dashboard",      -- Options: "dashboard", "factory", "production", "alerts"
  
  -- Alert settings
  alert_sound = true, -- Play sound on critical alerts
  alert_flash = true, -- Flash screen on alerts
  alert_history_size = 5, -- Number of alerts to keep in history
  
  -- Production calculation settings
  calculation_interval = 5, -- Seconds between recalculating production/deficits
  deficit_threshold = -5,   -- IPM deficit threshold for warnings
  surplus_threshold = 50,   -- IPM surplus threshold for warnings
  
  -- Command settings
  command_timeout = 5000, -- Milliseconds to wait for command acknowledgment
  command_retry_attempts = 3, -- Number of retries for failed commands
  
  -- Factory monitoring
  factory_timeout = 15, -- Seconds before considering factory offline
  
  -- Automatic control (optional)
  enable_auto_control = false, -- Enable automatic production balancing
  auto_control_interval = 30, -- Seconds between auto-control decisions
  
  -- Logging
  enable_logging = true,
  log_file = "scada.log",
  log_calculations = false,
  log_commands = true,
  log_alerts = true 
}
