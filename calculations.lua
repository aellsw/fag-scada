-- SCADA Production Calculations
-- Calculates deficits, surpluses, and production metrics

local recipes = require("scada.recipes")

local calculations = {}

-- Calculate total production and consumption for each item type
function calculations.calculate_item_balance(factories)
  local item_balance = {}
  
  -- Iterate through all factories and modules
  for factory_id, factory_data in pairs(factories) do
    if factory_data.modules then
      for module_id, module_data in pairs(factory_data.modules) do
        -- Get recipe for this module
        local recipe, recipe_type = recipes.get_recipe(module_id)
        
        if recipe and module_data.items_per_min and module_data.enabled then
          local ipm = module_data.items_per_min
          
          -- Add to production for what it produces
          if recipe.produces then
            item_balance[recipe.produces] = item_balance[recipe.produces] or {
              produced = 0,
              consumed = 0,
              producers = {},
              consumers = {}
            }
            
            item_balance[recipe.produces].produced = 
              item_balance[recipe.produces].produced + ipm
            
            table.insert(item_balance[recipe.produces].producers, {
              module_id = module_id,
              factory_id = factory_id,
              rate = ipm
            })
          end
          
          -- Add to consumption for what it consumes
          if recipe.consumes then
            -- Calculate input rate needed
            local input_rate = recipes.calculate_required_input(recipe_type, ipm)
            
            item_balance[recipe.consumes] = item_balance[recipe.consumes] or {
              produced = 0,
              consumed = 0,
              producers = {},
              consumers = {}
            }
            
            item_balance[recipe.consumes].consumed = 
              item_balance[recipe.consumes].consumed + input_rate
            
            table.insert(item_balance[recipe.consumes].consumers, {
              module_id = module_id,
              factory_id = factory_id,
              rate = input_rate
            })
          end
        end
      end
    end
  end
  
  return item_balance
end

-- Calculate net balance (positive = surplus, negative = deficit)
function calculations.calculate_net_balance(item_balance)
  local net_balance = {}
  
  for item_type, balance_data in pairs(item_balance) do
    net_balance[item_type] = {
      produced = balance_data.produced,
      consumed = balance_data.consumed,
      net = balance_data.produced - balance_data.consumed,
      producers = balance_data.producers,
      consumers = balance_data.consumers
    }
  end
  
  return net_balance
end

-- Identify deficits (items with negative balance)
function calculations.find_deficits(net_balance, threshold)
  threshold = threshold or -5  -- Default: deficit of 5+ IPM
  local deficits = {}
  
  for item_type, balance in pairs(net_balance) do
    if balance.net < threshold then
      table.insert(deficits, {
        item_type = item_type,
        deficit = math.abs(balance.net),
        produced = balance.produced,
        consumed = balance.consumed,
        severity = calculations.calculate_deficit_severity(balance.net)
      })
    end
  end
  
  -- Sort by severity (largest deficit first)
  table.sort(deficits, function(a, b)
    return a.deficit > b.deficit
  end)
  
  return deficits
end

-- Identify surpluses (items with positive balance)
function calculations.find_surpluses(net_balance, threshold)
  threshold = threshold or 50  -- Default: surplus of 50+ IPM
  local surpluses = {}
  
  for item_type, balance in pairs(net_balance) do
    if balance.net > threshold then
      table.insert(surpluses, {
        item_type = item_type,
        surplus = balance.net,
        produced = balance.produced,
        consumed = balance.consumed
      })
    end
  end
  
  -- Sort by size (largest surplus first)
  table.sort(surpluses, function(a, b)
    return a.surplus > b.surplus
  end)
  
  return surpluses
end

-- Calculate deficit severity
function calculations.calculate_deficit_severity(net_balance)
  local abs_deficit = math.abs(net_balance)
  
  if abs_deficit >= 100 then
    return "critical"
  elseif abs_deficit >= 50 then
    return "high"
  elseif abs_deficit >= 20 then
    return "medium"
  else
    return "low"
  end
end

-- Calculate factory-wide statistics
function calculations.calculate_factory_stats(factory_data)
  local stats = {
    total_modules = 0,
    active_modules = 0,
    inactive_modules = 0,
    total_stress = 0,
    total_capacity = 0,
    total_rpm = 0,
    total_ipm = 0
  }
  
  if not factory_data or not factory_data.modules then
    return stats
  end
  
  for module_id, module_data in pairs(factory_data.modules) do
    stats.total_modules = stats.total_modules + 1
    
    if module_data.enabled then
      stats.active_modules = stats.active_modules + 1
    else
      stats.inactive_modules = stats.inactive_modules + 1
    end
    
    stats.total_stress = stats.total_stress + (module_data.stress_units or 0)
    stats.total_capacity = stats.total_capacity + (module_data.stress_capacity or 0)
    stats.total_rpm = stats.total_rpm + math.abs(module_data.rpm or 0)
    stats.total_ipm = stats.total_ipm + (module_data.items_per_min or 0)
  end
  
  -- Average RPM
  if stats.total_modules > 0 then
    stats.average_rpm = stats.total_rpm / stats.total_modules
  end
  
  -- Stress percentage
  if stats.total_capacity > 0 then
    stats.stress_percentage = (stats.total_stress / stats.total_capacity) * 100
  else
    stats.stress_percentage = 0
  end
  
  return stats
end

-- Calculate global statistics across all factories
function calculations.calculate_global_stats(factories)
  local global = {
    total_factories = 0,
    factories_online = 0,
    factories_offline = 0,
    total_modules = 0,
    active_modules = 0,
    total_stress = 0,
    total_capacity = 0,
    total_ipm = 0
  }
  
  local current_time = os.epoch("utc")
  local factory_timeout = 15000  -- 15 seconds
  
  for factory_id, factory_data in pairs(factories) do
    global.total_factories = global.total_factories + 1
    
    -- Check if factory is online
    local age = current_time - (factory_data.last_updated or 0)
    if age < factory_timeout then
      global.factories_online = global.factories_online + 1
      
      -- Calculate factory stats
      local factory_stats = calculations.calculate_factory_stats(factory_data)
      
      global.total_modules = global.total_modules + factory_stats.total_modules
      global.active_modules = global.active_modules + factory_stats.active_modules
      global.total_stress = global.total_stress + factory_stats.total_stress
      global.total_capacity = global.total_capacity + factory_stats.total_capacity
      global.total_ipm = global.total_ipm + factory_stats.total_ipm
    else
      global.factories_offline = global.factories_offline + 1
    end
  end
  
  if global.total_capacity > 0 then
    global.stress_percentage = (global.total_stress / global.total_capacity) * 100
  else
    global.stress_percentage = 0
  end
  
  return global
end

-- Suggest production adjustments
function calculations.suggest_adjustments(deficits, factories)
  local suggestions = {}
  
  for _, deficit_info in ipairs(deficits) do
    local item_type = deficit_info.item_type
    local deficit_amount = deficit_info.deficit
    
    -- Find modules that produce this item
    local potential_producers = {}
    
    for factory_id, factory_data in pairs(factories) do
      if factory_data.modules then
        for module_id, module_data in pairs(factory_data.modules) do
          local recipe = recipes.get_recipe(module_id)
          
          if recipe.produces == item_type then
            table.insert(potential_producers, {
              module_id = module_id,
              factory_id = factory_id,
              enabled = module_data.enabled,
              current_ipm = module_data.items_per_min or 0,
              rpm = module_data.rpm
            })
          end
        end
      end
    end
    
    -- Suggest enabling disabled producers or increasing speed
    if #potential_producers > 0 then
      local suggestion = {
        item_type = item_type,
        deficit = deficit_amount,
        actions = {}
      }
      
      -- First, suggest enabling disabled modules
      for _, producer in ipairs(potential_producers) do
        if not producer.enabled then
          table.insert(suggestion.actions, {
            action = "enable",
            module_id = producer.module_id,
            factory_id = producer.factory_id,
            expected_increase = 20  -- Estimated
          })
        end
      end
      
      -- If still short, suggest increasing speed
      if #suggestion.actions == 0 then
        -- Suggest increasing speed of existing producers
        for _, producer in ipairs(potential_producers) do
          if producer.enabled and producer.rpm < 128 then
            table.insert(suggestion.actions, {
              action = "increase_speed",
              module_id = producer.module_id,
              factory_id = producer.factory_id,
              current_rpm = producer.rpm,
              suggested_rpm = math.min(producer.rpm * 1.5, 128)
            })
          end
        end
      end
      
      if #suggestion.actions > 0 then
        table.insert(suggestions, suggestion)
      end
    end
  end
  
  return suggestions
end

return calculations
