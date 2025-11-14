-- SCADA Recipe Definitions
-- Defines what each machine type produces and consumes

local recipes = {}

-- Recipe database
-- Each recipe defines what a machine produces and what it consumes
recipes.database = {
  -- Crushing
  crusher = {
    name = "Crusher",
    produces = "crushed_ore",
    consumes = "raw_ore"
  },
  
  -- Washing (Bulk Washing)
  fan = {
    name = "Encased Fan (Washing)",
    produces = "nuggets",
    consumes = "crushed_ore"
  },
  
  -- Pressing
  press = {
    name = "Mechanical Press",
    produces = "sheets",
    consumes = "ingots"
  },
  
  -- Mixing
  mixer = {
    name = "Mechanical Mixer",
    produces = "mixed_material",
    consumes = "ingredients"
  },
  
  -- Milling
  millstone = {
    name = "Millstone",
    produces = "dust",
    consumes = "material"
  },
  
  -- Compacting
  compactor = {
    name = "Mechanical Compactor",
    produces = "compact_material",
    consumes = "loose_material"
  },
  
  -- Sawing
  saw = {
    name = "Mechanical Saw",
    produces = "planks",
    consumes = "logs"
  },
  
  -- Cutting
  cutter = {
    name = "Mechanical Cutter",
    produces = "cut_material",
    consumes = "block"
  },
  
  -- Deploying
  deployer = {
    name = "Mechanical Deployer",
    produces = "assembled_item",
    consumes = "components"
  },
  
  -- Item Application
  item_applicator = {
    name = "Item Applicator",
    produces = "applied_item",
    consumes = "base_item"
  }
}

-- Get recipe for a module based on module_id pattern
-- e.g., "crusher_01" -> crusher recipe
function recipes.get_recipe(module_id)
  -- Try to match module_id to recipe type
  for recipe_type, recipe_data in pairs(recipes.database) do
    if string.find(module_id:lower(), recipe_type) then
      return recipe_data, recipe_type
    end
  end
  
  -- Default/unknown recipe
  return {
    name = "Unknown Machine",
    produces = "unknown",
    consumes = "unknown"
  }, "unknown"
end

-- Note: Removed expected rate and efficiency calculations
-- All production tracking is now based solely on actual measured IPM

-- Item flow tracking
recipes.item_flows = {}

-- Register an item flow (what produces what)
function recipes.register_item_flow(item_name, producer_type, consumer_type)
  recipes.item_flows[item_name] = {
    producers = producer_type,
    consumers = consumer_type
  }
end

-- Common Create item flows
recipes.register_item_flow("crushed_ore", {"crusher"}, {"fan"})
recipes.register_item_flow("nuggets", {"fan"}, {"smelter"})
recipes.register_item_flow("ingots", {"smelter"}, {"press"})
recipes.register_item_flow("sheets", {"press"}, {"crafter"})

-- Production chain definitions
recipes.chains = {
  -- Iron processing chain
  iron = {
    {step = 1, machine = "crusher", input = "iron_ore", output = "crushed_iron"},
    {step = 2, machine = "fan", input = "crushed_iron", output = "iron_nuggets"},
    {step = 3, machine = "smelter", input = "iron_nuggets", output = "iron_ingots"},
    {step = 4, machine = "press", input = "iron_ingots", output = "iron_sheets"}
  },
  
  -- Steel processing chain
  steel = {
    {step = 1, machine = "mixer", input = "iron_ingots", output = "steel_mix"},
    {step = 2, machine = "smelter", input = "steel_mix", output = "steel_ingots"},
    {step = 3, machine = "press", input = "steel_ingots", output = "steel_sheets"}
  },
  
  -- Copper processing chain
  copper = {
    {step = 1, machine = "crusher", input = "copper_ore", output = "crushed_copper"},
    {step = 2, machine = "fan", input = "crushed_copper", output = "copper_nuggets"},
    {step = 3, machine = "smelter", input = "copper_nuggets", output = "copper_ingots"}
  }
}

-- Get production chain for a factory
function recipes.get_chain(factory_id)
  return recipes.chains[factory_id]
end

-- Material ratios (how many input items per output item)
recipes.ratios = {
  -- Crushing: 1 ore -> 1 crushed ore
  crusher = {input_per_output = 1.0},
  
  -- Washing: 1 crushed -> ~9 nuggets (on average)
  fan = {input_per_output = 0.11},  -- Inverted: need 0.11 crushed per nugget
  
  -- Pressing: 1 ingot -> 1 sheet
  press = {input_per_output = 1.0},
  
  -- Mixing: varies by recipe
  mixer = {input_per_output = 1.0},
  
  -- Millstone: 1 material -> 1 dust
  millstone = {input_per_output = 1.0}
}

-- Get material ratio for a machine type
function recipes.get_ratio(machine_type)
  return recipes.ratios[machine_type] or {input_per_output = 1.0}
end

-- Calculate required input rate based on output rate
function recipes.calculate_required_input(machine_type, output_rate)
  local ratio = recipes.get_ratio(machine_type)
  return output_rate * ratio.input_per_output
end

return recipes
