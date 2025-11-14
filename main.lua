-- SCADA Computer Main Program
-- Tier 3: Global monitoring, calculations, and control

-- Load dependencies
local protocol = require("fag.protocol")
local network = require("fag.network")
local recipes = require("scada.recipes")
local calculations = require("scada.calculations")
local config = require("scada.config")

-- SCADA state
local state = {
  running = true,
  factories = {},  -- All factory data indexed by factory_id
  alerts = {},     -- Active alerts
  last_calculation = 0,
  startup_time = os.epoch("utc"),
  pending_commands = {}
}

-- Current analysis
local analysis = {
  item_balance = {},
  net_balance = {},
  deficits = {},
  surpluses = {},
  global_stats = {}
}

-- Logging
local function log(message)
  if config.enable_logging then
    local timestamp = os.date("%H:%M:%S")
    local log_msg = "[" .. timestamp .. "] " .. message
    
    if config.log_file then
      local file = fs.open(config.log_file, "a")
      file.writeLine(log_msg)
      file.close()
    end
    
    print(log_msg)
  end
end

-- Handle factory snapshot
local function handle_factory_snapshot(msg, sender_id)
  local factory_id = msg.factory_id
  
  -- Store factory data
  state.factories[factory_id] = {
    factory_id = factory_id,
    modules = msg.modules,
    summary = msg.summary,
    lan_status = msg.lan_status,
    last_updated = msg.timestamp,
    sender_id = sender_id
  }
  
  -- Log first contact
  if not state.factories[factory_id].initialized then
    log("Factory registered: " .. factory_id)
    state.factories[factory_id].initialized = true
  end
end

-- Handle factory alert
local function handle_factory_alert(msg, sender_id)
  -- Store alert
  local alert = {
    factory_id = msg.factory_id,
    alert_type = msg.alert_type,
    severity = msg.severity,
    affected_modules = msg.affected_modules,
    details = msg.details,
    message = msg.message,
    timestamp = msg.timestamp,
    acknowledged = false
  }
  
  table.insert(state.alerts, alert)
  
  -- Limit alert history
  while #state.alerts > config.alert_history_size do
    table.remove(state.alerts, 1)
  end
  
  -- Log alert
  if config.log_alerts then
    log("ALERT [" .. msg.severity .. "] " .. msg.factory_id .. ": " .. msg.message)
  end
  
  -- Sound/flash for critical alerts
  if msg.severity == protocol.SEVERITY.CRITICAL then
    if config.alert_sound then
      -- Play sound (if speaker peripheral available)
      local speaker = peripheral.find("speaker")
      if speaker then
        speaker.playSound("minecraft:entity.experience_orb.pickup", 1.0, 1.0)
      end
    end
  end
end

-- Handle factory acknowledgment
local function handle_factory_ack(msg, sender_id)
  local command_id = msg.command_id
  
  if state.pending_commands[command_id] then
    state.pending_commands[command_id].ack_received = true
    state.pending_commands[command_id].ack_time = os.epoch("utc")
    state.pending_commands[command_id].results = msg.results
    state.pending_commands[command_id].commands_forwarded = msg.commands_forwarded
    
    if config.log_commands then
      log("Command " .. command_id .. " ACK from " .. msg.factory_id .. 
          " (" .. msg.commands_forwarded .. " forwarded)")
    end
  end
end

-- Send command to factory
local function send_factory_command(factory_id, command_type, targets, priority, reason)
  local factory_data = state.factories[factory_id]
  
  if not factory_data then
    log("ERROR: Unknown factory " .. factory_id)
    return false
  end
  
  -- Generate command ID
  local cmd_id = protocol.generate_command_id()
  
  -- Build command
  local cmd = protocol.build_message(protocol.MSG_TYPES.SCADA_COMMAND, {
    command_id = cmd_id,
    target_factory = factory_id,
    command = command_type,
    targets = targets,
    source = protocol.SOURCES.SCADA_AUTO,
    priority = priority or protocol.PRIORITY.NORMAL,
    override_local = false,
    reason = reason
  })
  
  -- Track command
  state.pending_commands[cmd_id] = {
    sent_at = os.epoch("utc"),
    factory = factory_id,
    command = command_type,
    targets = targets,
    ack_received = false
  }
  
  -- Send to factory LAN
  local success, err = network.send(factory_data.sender_id, cmd)
  if not success then
    log("ERROR: Failed to send command to " .. factory_id .. ": " .. err)
    return false
  end
  
  if config.log_commands then
    log("Sent command " .. cmd_id .. " to " .. factory_id .. ": " .. command_type)
  end
  
  return true, cmd_id
end

-- Run production calculations
local function run_calculations()
  -- Calculate item balance
  analysis.item_balance = calculations.calculate_item_balance(state.factories)
  
  -- Calculate net balance
  analysis.net_balance = calculations.calculate_net_balance(analysis.item_balance)
  
  -- Find deficits
  analysis.deficits = calculations.find_deficits(
    analysis.net_balance, 
    config.deficit_threshold
  )
  
  -- Find surpluses
  analysis.surpluses = calculations.find_surpluses(
    analysis.net_balance,
    config.surplus_threshold
  )
  
  -- Calculate global stats
  analysis.global_stats = calculations.calculate_global_stats(state.factories)
  
  -- Log if enabled
  if config.log_calculations then
    log("Calculations: " .. #analysis.deficits .. " deficits, " .. 
        #analysis.surpluses .. " surpluses")
  end
  
  state.last_calculation = os.epoch("utc")
end

-- Handle incoming messages
local function handle_message(msg, sender_id)
  network.update_last_seen(sender_id)
  
  if msg.msg_type == protocol.MSG_TYPES.FACTORY_SNAPSHOT then
    handle_factory_snapshot(msg, sender_id)
    
  elseif msg.msg_type == protocol.MSG_TYPES.FACTORY_ALERT then
    handle_factory_alert(msg, sender_id)
    
  elseif msg.msg_type == protocol.MSG_TYPES.FACTORY_ACK then
    handle_factory_ack(msg, sender_id)
    
  elseif msg.msg_type == protocol.MSG_TYPES.HEARTBEAT then
    -- Track heartbeats
    
  elseif msg.msg_type == protocol.MSG_TYPES.EMERGENCY_STOP then
    log("EMERGENCY STOP propagated")
    
  else
    log("Received unexpected message type: " .. msg.msg_type)
  end
end

-- Check for command timeouts
local function check_command_timeouts()
  local now = os.epoch("utc")
  
  for cmd_id, cmd_data in pairs(state.pending_commands) do
    local age = now - cmd_data.sent_at
    
    if age > config.command_timeout and not cmd_data.ack_received then
      log("WARNING: Command " .. cmd_id .. " timeout (no ACK from " .. 
          cmd_data.factory .. ")")
      
      -- Retry if under limit
      if not cmd_data.retries or cmd_data.retries < config.command_retry_attempts then
        cmd_data.retries = (cmd_data.retries or 0) + 1
        log("Retrying command " .. cmd_id .. " (attempt " .. cmd_data.retries .. ")")
        -- Resend would go here
      else
        -- Give up
        state.pending_commands[cmd_id] = nil
      end
    end
    
    -- Clean up old acknowledged commands
    if cmd_data.ack_received and age > 60000 then  -- 60 seconds
      state.pending_commands[cmd_id] = nil
    end
  end
end

-- Send heartbeat
local function send_heartbeat()
  local msg = protocol.build_message(protocol.MSG_TYPES.HEARTBEAT, {
    sender_id = os.getComputerID(),
    sender_type = "scada",
    uptime = os.epoch("utc") - state.startup_time,
    status = "operational",
    factories_online = analysis.global_stats.factories_online or 0
  })
  
  network.broadcast(msg)
end

-- Display status on terminal
local function display_status()
  term.clear()
  term.setCursorPos(1, 1)
  
  print("=== SCADA Control Center ===")
  print("Computer ID: " .. os.getComputerID())
  print("")
  
  -- Global statistics
  local stats = analysis.global_stats
  print("Factories: " .. (stats.factories_online or 0) .. " / " .. 
        (stats.total_factories or 0) .. " online")
  print("Modules: " .. (stats.total_modules or 0) .. " (" .. 
        (stats.active_modules or 0) .. " active)")
  print("")
  
  print("Stress: " .. (stats.total_stress or 0) .. " / " .. 
        (stats.total_capacity or 0) .. " SU")
  if stats.total_capacity and stats.total_capacity > 0 then
    print("Stress %: " .. string.format("%.1f%%", stats.stress_percentage or 0))
  end
  print("")
  
  print("Total IPM: " .. string.format("%.1f", stats.total_ipm or 0))
  print("")
  
  -- Deficits
  if #analysis.deficits > 0 then
    print("--- DEFICITS ---")
    for i = 1, math.min(3, #analysis.deficits) do
      local deficit = analysis.deficits[i]
      print(deficit.item_type .. ": -" .. string.format("%.1f", deficit.deficit) .. 
            " IPM (" .. deficit.severity .. ")")
    end
    if #analysis.deficits > 3 then
      print("... " .. (#analysis.deficits - 3) .. " more")
    end
    print("")
  end
  
  -- Alerts
  local active_alerts = 0
  for _, alert in ipairs(state.alerts) do
    if not alert.acknowledged then
      active_alerts = active_alerts + 1
    end
  end
  
  if active_alerts > 0 then
    print("ALERTS: " .. active_alerts .. " active")
  end
  
  print("")
  print("Last calc: " .. string.format("%.1f", 
        (os.epoch("utc") - state.last_calculation) / 1000.0) .. "s ago")
  print("")
  print("Press Ctrl+T to stop")
end

-- Main program
local function main()
  print("=== SCADA Computer Starting ===")
  print("Monitoring " .. #config.factories .. " factories")
  print("")
  
  -- Initialize network
  log("Initializing network...")
  local success, err = network.init()
  if not success then
    log("FATAL: Failed to initialize network: " .. err)
    return
  end
  log("Network initialized on " .. network.modem_side)
  
  -- Enable logging
  if config.enable_logging then
    network.enable_logging(config.log_file)
  end
  
  -- Register factory computers
  for _, factory_info in ipairs(config.factories) do
    network.register_computer(factory_info.lan_id, factory_info.id, "factory_lan")
    log("Registered factory: " .. factory_info.id .. " (ID " .. factory_info.lan_id .. ")")
  end
  
  -- Send initial heartbeat
  send_heartbeat()
  log("Startup complete")
  
  -- Main loop timers
  local heartbeat_timer = os.startTimer(30)
  local display_timer = os.startTimer(1)
  local calculation_timer = os.startTimer(config.calculation_interval)
  
  while state.running do
    -- Check for incoming messages (non-blocking)
    local msg, sender_id = network.receive_nonblocking()
    if msg then
      handle_message(msg, sender_id)
    end
    
    -- Check command timeouts
    check_command_timeouts()
    
    -- Handle timers
    local event, param = os.pullEvent()
    
    if event == "timer" then
      if param == heartbeat_timer then
        send_heartbeat()
        heartbeat_timer = os.startTimer(30)
        
      elseif param == display_timer then
        display_status()
        display_timer = os.startTimer(config.ui_refresh_rate)
        
      elseif param == calculation_timer then
        run_calculations()
        calculation_timer = os.startTimer(config.calculation_interval)
      end
    end
    
    sleep(0.05)
  end
  
  log("SCADA shutting down")
  term.clear()
  term.setCursorPos(1, 1)
  print("SCADA stopped")
end

-- Run with error handling
local success, err = pcall(main)
if not success then
  term.clear()
  term.setCursorPos(1, 1)
  print("ERROR: " .. tostring(err))
  print("")
  print("Check log file: " .. config.log_file)
end
