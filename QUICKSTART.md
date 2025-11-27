# QUICK START GUIDE
## TACO Custom Chunk Loading Engine

Quick guide to getting started with the chunk engine in 10 minutes.

---

## Step 1: Set Up the Structure (2 minutes)

### 1.1 Create Folders

In **ReplicatedStorage** create:
```
ReplicatedStorage/
└── ChunkEngine/
```

In **ServerScriptService**:
```
ServerScriptService/
└── Streamer (Script)
```

In **ServerStorage**:
```
ServerStorage/
├── ChunkStorage/
└── ChunkTemplates/
```

### 1.2 Upload Files

Copy all `.lua` files to `ReplicatedStorage/ChunkEngine/`:
- Config.lua
- ChunkData.lua
- ChunkManager.lua
- LODSystem.lua
- Octree.lua
- ChunkRegistry.lua
- PreloadManager.lua
- ExampleChunkDefinition.lua

Copy `Streamer.lua` to `ServerScriptService/`.

---

## Step 2: Basic Configuration (2 minutes)

Open `Config.lua` and edit:

```lua
-- IMPORTANT SETTINGS
Config.ChunkSize = Vector3.new(128, 128, 128) -- Size of one chunk
Config.LoadDistance = 512 -- Start loading at this distance
Config.UnloadDistance = 768 -- Unload at this distance
Config.MaxLoadedChunks = 50 -- Maximum number of chunks loaded at once

-- ENABLE BASIC FEATURES
Config.LODEnabled = true -- LOD system
Config.PreloadingEnabled = true -- Predictive loading
Config.MultiplayerMode = true -- Multiplayer

-- DEBUG (disable in production)
Config.DebugMode = true -- Debug logs
Config.LogChunkOperations = true -- Log operations
Config.VisualizeChunks = false -- Visualize chunks (performance hit!)
```

---

## Step 3: Create Your First Map (3 minutes)

### Method A: Quick Test (Recommended for beginners)

There is a `GenerateChunks()` function already built into `Streamer.lua`. Use it:

```lua
-- Find this section in Streamer.lua:
if not loaded then
print("[Streamer] No chunks found, generating test world...")
GenerateChunks(8, 2, 8) -- 8x2x8 = 128 chunks
end
```

This will automatically create a test world. **You can test it right away!**

### Method B: Custom Chunk (For Production)

1. Create a model in your workspace (e.g. a part of a city)
2. Move it to `ServerStorage/ChunkTemplates/`
3. Name it (e.g. "Town_Terrain")
4. Create a ModuleScript in `ServerStorage/ChunkStorage/0,0,0.lua`:

```lua
return {
Tags = {"Town"},
Priority = 90,

Layers = {
Terrain = {
Model = game.ServerStorage.ChunkTemplates.Town_Terrain
}
}
}
```

---

## Step 4: Run (1 minute)

1. Click **Play** in Roblox Studio
2. Watch the Output - you should see:

```
[Streamer] Initializing Chunk System...
[Streamer] Mode: Server
[ChunkRegistry] Loaded X chunks
[Streamer] Generated 128 procedural chunks
[Streamer] Chunk system started!
```

3. **Move around in the game** - chunks will load automatically!

---

## Step 5: Testing (2 minutes)

### Check Performance

In Output every 5 seconds you will see:

```
= RequiresActivation = true,
Spawners = {
{
Type = "Guard",
Position = {10, 0, 10},
Wander = true,
WanderRadius = 20
}
}
}
}
```

### Change Priority

```lua
-- VIP area = load first
chunk.Priority = 100
chunk:AddTag("VIPArea")
```

### Custom LOD

```lua
-- Config.lua
Config.LODLevels = {
{Distance = 0, Name = "High", DetailLevel = 1.0},
{Distance = 200, Name = "Medium", DetailLevel = 0.6},
{Distance = 400, Name = "Low", DetailLevel = 0.3}
}
```

---

## Common Problems and Solutions

### Problem: Chunky not loading

**Solution:**
1. Check Output - are there any errors?
2. Check `Config.ChunkStorageLocation`
3. Try to enable debug:
```lua
Config.DebugMode = true
Config.LogChunkOperations = true
```

### Problem: FPS drops while loading

**Solution:**
```lua
-- Reduce rate limits
Config.MaxChunksPerFrame = 1
Config.MaxChunksPerSecond = 3

-- Async loading
Config.UseAsyncLoading = true
```

### Problem: Chunks are unloading too early

**Solution:**
```lua
Config.UnloadDistance = 1024 -- Increase
Config.PlayerCheckRadius = 128 -- Increase
```

---

## Done! 🎉

Now you have a working chunk loading system!

### What next?

1. **Study the documentation** (`DOCUMENTATION.md`) for advanced features
2. **Create your own chunks** according to `ExampleChunkDefinition.lua`
3. **Optimize** to your game's needs
4. **Extend** with your own entities and systems

---
emote Function:

```lua
-- Get stats
_G.ChunkManager:GetStats()

-- Force load chunk
_G.ChunkManager:ForceLoadChunk(Vector3.new(0, 0, 0))

-- Chunk info
_G.ChunkManager:GetChunkInfo(Vector3.new(0, 0, 0))

-- Turn visualization on/off
Config.VisualizeChunks = not Config.VisualizeChunks
```

---

## Example: Full Workflow

### 1. Create Town Area

```lua
-- ServerStorage/ChunkStorage/Town_Center.lua
return {
Tags = {"Town", "Spawn"},
Priority = 95,
IsPersistent = true, -- Never unload

Layers = {
Terrain = {
Model = game.ServerStorage.ChunkTemplates.Town_Ground
}, 
Structures = { 
Model = game.ServerStorage.ChunkTemplates.Town_Buildings 
}, 
NPC = { 
Spawners = { 
{Type = "Merchant", Position = {50, 0, 50}}, 
{Type = "Guard", Position = {10, 0, 10}} 
} 
}, 
Lighting = { 
Lights = { 
{Type = "StreetLight", Position = {20, 5, 20}} 
} 
} 
}
}
```

### 2. Create a Forest Area

```lua
-- Procedurally
GenerateChunks(5, 1, 5) -- 5x5 grid

-- Or manually
return { 
Tags = {"Forest", "Environment"}, 
Priorities = 60, 

Layers = { 
Terrain = { 
Generator = function(pos, size) 
local folder = Instance.new("Folder") 
-- Generate trees, rocks, etc. 
return folder 
end 
} 
}
}
```

### 3. Connect Events

```lua
-- In Streamer.lua
manager.Events.OnChunkActivated.Event:Connect(function(chunk) 
if chunk:HasTag("NPC") then 
-- Spawn NPCs 
NPCSystem:SpawnInChunk(chunk) 
end
end)

manager.Events.OnChunkDeactivated.Event:Connect(function(chunk) 
if chunk:HasTag("NPC") then 
-- Despawn NPCs 
NPCSystem:DespawnInChunk(chunk) 
end
end)
```

---

## More Resources

- **Full Documentation**: `DOCUMENTATION.md`
- **Chunk Examples**: `ExampleChunkDefinition.lua`
- **Registry System**: `ChunkRegistry.lua`

---

## Tips & Tricks

### Performance Tips

1. **Use LOD** - saves FPS
2. **Multi-layer chunks** - load terrain first, decorations later
3. **Tag correctly** - better prioritization
4. **Persistent spawn** - mark as `IsPersistent = true`

### Organization Tips

1. **One chunk = one region** (town, forest, cave)
2. **Use tags consistently** ("Town", "Cave", "Boss")
3. **Template models** in `ChunkTemplates/` for reuse
4. **ChunkRegistry** for centralized management

### Development Tips

1. **Debug mode ON** during development
2. **Visualization ON** for placement
3. **Lower distances** for faster testing:
```lua
Config.LoadDistance = 256
Config.UnloadDistance = 384
```

---

**Have fun building your world! 🌍**

Created for TACO | Version 1.0.0
## Useful Commands (For Debug)

In the **Command Bar** or via R
