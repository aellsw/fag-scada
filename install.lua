-- SCADA Computer Installer
-- Run with: wget run https://raw.githubusercontent.com/aellsw/fag-scada/main/install.lua

local GITHUB_USER = "aellsw"
local REPO = "fag-scada"
local BRANCH = "main"

-- Map of GitHub path -> Local path
local files = {
  {github = "fag/protocol.lua", local_path = "fag/protocol.lua"},
  {github = "fag/network.lua", local_path = "fag/network.lua"},
  {github = "main.lua", local_path = "main.lua"},
  {github = "calculations.lua", local_path = "scada/calculations.lua"},
  {github = "recipes.lua", local_path = "scada/recipes.lua"},
  {github = "config.lua", local_path = "scada/config.lua"}
}

print("=== SCADA Computer Installer ===")
print("Downloading from GitHub...")
print("")

-- Create directories
if not fs.exists("fag") then
  fs.makeDir("fag")
  print("Created fag/ directory")
end

if not fs.exists("scada") then
  fs.makeDir("scada")
  print("Created scada/ directory")
end

-- Download each file
local success_count = 0
local fail_count = 0

for _, file in ipairs(files) do
  local url = string.format(
    "https://raw.githubusercontent.com/%s/%s/%s/%s",
    GITHUB_USER, REPO, BRANCH, file.github
  )
  
  print("Downloading " .. file.local_path .. "...")
  
  local response = http.get(url)
  if response then
    local content = response.readAll()
    response.close()
    
    local handle = fs.open(file.local_path, "w")
    handle.write(content)
    handle.close()
    
    print("  OK")
    success_count = success_count + 1
  else
    print("  FAILED")
    fail_count = fail_count + 1
  end
end

print("")
print("=== Installation Complete ===")
print("Downloaded: " .. success_count .. " files")
if fail_count > 0 then
  print("Failed: " .. fail_count .. " files")
end
print("")
print("Next steps:")
print("1. Edit config.lua if needed")
print("2. Run: main")
