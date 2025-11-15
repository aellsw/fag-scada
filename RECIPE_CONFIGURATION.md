# Recipe Configuration Guide

This guide explains how to configure what items each module produces and consumes for SCADA tracking.

## How Recipe Matching Works

The SCADA system automatically matches modules to recipes based on their **module_id** name.

### Automatic Matching

When a module reports data, SCADA looks at the `module_id` and searches for a matching recipe type in `recipes.lua`.

**Example:**
- Module with `module_id = "crusher_01"` → matches **crusher** recipe
- Module with `module_id = "fan_iron_1"` → matches **fan** recipe
- Module with `module_id = "press_02"` → matches **press** recipe

The matching is done by searching for the recipe type name **anywhere** in the module_id (case-insensitive).

## Step-by-Step Configuration

### 1. Choose Your Module ID

In your **module** computer's `config.lua`:

```lua
module_id = "crusher_01",  -- Name that indicates what machine this is
```

**Naming Convention:** `<machine_type>_<number>` or `<machine_type>_<location>_<number>`

Examples:
- `"crusher_01"`
- `"fan_iron_1"`
- `"press_steel_02"`
- `"mixer_main"`

### 2. Define the Recipe in SCADA

In the **SCADA** computer's `recipes.lua`, add or edit the recipe definition:

```lua
recipes.database = {
  crusher = {
    name = "Crusher",
    produces = "crushed_ore",  -- What this machine outputs
    consumes = "raw_ore"       -- What this machine uses as input
  },
  
  -- Add your machine type here
  your_machine = {
    name = "Your Machine Name",
    produces = "output_item",
    consumes = "input_item"
  }
}
```

### 3. Example Configurations

#### Example 1: Iron Crusher
**Module config.lua:**
```lua
module_id = "crusher_iron_01",
factory_id = "iron",
```

**SCADA recipes.lua:**
```lua
crusher = {
  name = "Crusher",
  produces = "crushed_iron_ore",
  consumes = "iron_ore"
},
```

#### Example 2: Fan/Washer
**Module config.lua:**
```lua
module_id = "fan_copper_1",
factory_id = "copper",
```

**SCADA recipes.lua:**
```lua
fan = {
  name = "Encased Fan (Washing)",
  produces = "copper_nuggets",
  consumes = "crushed_copper_ore"
},
```

#### Example 3: Item Drain
**Module config.lua:**
```lua
module_id = "drain_01",
factory_id = "test",
```

**SCADA recipes.lua:**
```lua
drain = {
  name = "Item Drain",
  produces = "void",      -- If it destroys items
  consumes = "any_item"   -- What goes in
},
```

## Available Recipe Types (Default)

Current recipes defined in `recipes.lua`:

| Recipe Type      | Module ID Contains | Example Module ID    |
|------------------|-------------------|---------------------|
| `crusher`        | "crusher"         | `crusher_01`        |
| `fan`            | "fan"             | `fan_iron_1`        |
| `press`          | "press"           | `press_02`          |
| `mixer`          | "mixer"           | `mixer_main`        |
| `millstone`      | "millstone"       | `millstone_01`      |
| `compactor`      | "compactor"       | `compactor_01`      |
| `saw`            | "saw"             | `saw_01`            |
| `cutter`         | "cutter"          | `cutter_01`         |
| `deployer`       | "deployer"        | `deployer_01`       |
| `item_applicator`| "applicator"      | `applicator_01`     |
| `drain`          | "drain"           | `drain_01`          |

## Adding a New Machine Type

1. Edit `recipes.lua` in the SCADA computer
2. Add a new entry to `recipes.database`:

```lua
your_new_machine = {
  name = "Display Name",
  produces = "output_item_name",
  consumes = "input_item_name"
},
```

3. Name your module to include the recipe type:
```lua
module_id = "your_new_machine_01"
```

4. Restart SCADA to load the new recipe

## Item Names

The `produces` and `consumes` fields are **descriptive labels** for tracking. They should:
- Be consistent across your factory
- Match between producer and consumer modules
- Be human-readable (shown in SCADA UI)

**Example Flow:**
```
Module 1: produces "crushed_ore", consumes "raw_ore"
Module 2: produces "nuggets", consumes "crushed_ore"  ← matches output of Module 1
Module 3: produces "ingots", consumes "nuggets"        ← matches output of Module 2
```

## Troubleshooting

### Module Shows "Unknown Machine"
- Check that the module_id contains the recipe type name
- Verify the recipe exists in `recipes.lua`
- Check for typos (case-insensitive but must match)

### Production Not Tracking Correctly
- Verify `produces` and `consumes` fields match between modules
- Check that item names are consistent across the production chain
- Ensure modules are reporting items_per_min > 0

### Recipe Not Loading
- Restart the SCADA computer after editing `recipes.lua`
- Check for Lua syntax errors in `recipes.lua`
- Look for missing commas or brackets
