--[[
    CHUNK REGISTRY
    Centralized registry of all chunks in the world
    
    This module provides a single place to define all chunks.
    Alternatively, you can load chunks from individual ModuleScripts.
    
    Author: TACO Custom Chunk Engine
    Version: 1.0.0
]]

--[[
    USAGE:
    Place this in ReplicatedStorage/ChunkEngine/ChunkRegistry
    
    The Streamer script will automatically load chunks from here
    if it exists.
]]

local ChunkRegistry = {}

--============================================
-- HELPER FUNCTIONS
--============================================

local function CreateChunk(x, y, z, tags, priority, layers)
	return {
		Position = {x, y, z},
		Size = {128, 128, 128},  -- Default chunk size
		Tags = tags or {},
		Priority = priority or 50,
		IsPersistent = false,
		Layers = layers or {}
	}
end

--============================================
-- WORLD DEFINITION
--============================================

-- TOWN AREA (0,0,X)
table.insert(ChunkRegistry, CreateChunk(
	0, 0, 0,
	{"Town", "Structures", "NPC"},
	90,
	{
		Terrain = {
			Priority = 100,
			LoadFirst = true,
			Model = nil  -- Reference your model here
		},
		Structures = {
			Priority = 90,
			LoadFirst = true,
			Model = nil
		},
		NPC = {
			Priority = 85,
			RequiresActivation = true,
			Spawners = {
				{Type = "Guard", Position = {10, 0, 10}},
				{Type = "Merchant", Position = {50, 0, 50}}
			}
		}
	}
	))

table.insert(ChunkRegistry, CreateChunk(
	0, 0, 1,
	{"Town", "Structures"},
	85,
	{
		Terrain = {Model = nil},
		Structures = {Model = nil}
	}
	))

table.insert(ChunkRegistry, CreateChunk(
	1, 0, 0,
	{"Town", "Structures"},
	85,
	{
		Terrain = {Model = nil},
		Structures = {Model = nil}
	}
	))

table.insert(ChunkRegistry, CreateChunk(
	1, 0, 1,
	{"Town", "Structures"},
	85,
	{
		Terrain = {Model = nil},
		Structures = {Model = nil}
	}
	))

-- FOREST AREA (2,0,X)
table.insert(ChunkRegistry, CreateChunk(
	2, 0, 0,
	{"Forest", "Environment"},
	60,
	{
		Terrain = {Model = nil},
		Props = {Model = nil}
	}
	))

table.insert(ChunkRegistry, CreateChunk(
	2, 0, 1,
	{"Forest", "Environment"},
	60,
	{
		Terrain = {Model = nil},
		Props = {Model = nil}
	}
	))

-- CAVE ENTRANCE (3,0,0)
table.insert(ChunkRegistry, CreateChunk(
	3, 0, 0,
	{"Cave", "Entrance"},
	75,
	{
		Terrain = {Model = nil},
		Structures = {Model = nil},
		Lighting = {
			Lights = {
				{Type = "Torch", Position = {10, 5, 10}, Color = {255, 150, 50}}
			}
		}
	}
	))

-- UNDERGROUND CAVE (3,-1,0)
table.insert(ChunkRegistry, CreateChunk(
	3, -1, 0,
	{"Cave", "Underground", "Dark"},
	70,
	{
		Terrain = {Model = nil},
		Lighting = {
			Lights = {
				{Type = "Crystal", Position = {30, 10, 30}, Color = {100, 200, 255}}
			}
		},
		Effects = {
			Particles = {
				{Type = "Drip", Position = {20, 20, 20}}
			}
		}
	}
	))

-- MOUNTAIN AREA (4,1,X)
table.insert(ChunkRegistry, CreateChunk(
	4, 1, 0,
	{"Mountain", "Environment"},
	55,
	{
		Terrain = {Model = nil}
	}
	))

table.insert(ChunkRegistry, CreateChunk(
	4, 2, 0,
	{"Mountain", "Peak"},
	55,
	{
		Terrain = {Model = nil},
		Effects = {
			Particles = {
				{Type = "Snow", Position = {64, 50, 64}}
			}
		}
	}
	))

-- BOSS ARENA (-1,0,0)
table.insert(ChunkRegistry, CreateChunk(
	-1, 0, 0,
	{"BossArea", "Arena"},
	100,
	{
		Terrain = {
			Priority = 100,
			LoadFirst = true,
			Model = nil
		},
		Structures = {
			Priority = 95,
			Model = nil
		},
		Lighting = {
			Priority = 90,
			Lights = {
				{Type = "Dramatic", Position = {64, 30, 64}, Color = {255, 0, 0}}
			}
		},
		Effects = {
			Priority = 85,
			Particles = {
				{Type = "Fog", Position = {64, 0, 64}}
			}
		}
	}
	))

-- DESERT AREA (5,0,X)
for x = 5, 8 do
	for z = 0, 3 do
		table.insert(ChunkRegistry, CreateChunk(
			x, 0, z,
			{"Desert", "Environment"},
			40,
			{
				Terrain = {Model = nil},
				Props = {Model = nil}
			}
			))
	end
end

-- OCEAN AREA (0,0,5+)
for z = 5, 10 do
	table.insert(ChunkRegistry, CreateChunk(
		0, 0, z,
		{"Ocean", "Water"},
		35,
		{
			Terrain = {Model = nil}
		}
		))
end

-- VILLAGE (10,0,0)
table.insert(ChunkRegistry, CreateChunk(
	10, 0, 0,
	{"Village", "Structures", "NPC"},
	85,
	{
		Terrain = {Model = nil},
		Structures = {Model = nil},
		NPC = {
			RequiresActivation = true,
			Spawners = {
				{Type = "Villager", Position = {20, 0, 20}},
				{Type = "Villager", Position = {40, 0, 40}},
				{Type = "Villager", Position = {60, 0, 60}}
			}
		}
	}
	))

--============================================
-- PROCEDURAL GENERATION EXAMPLE
--============================================

-- Generate a large grid of procedural chunks
local function GenerateProceduralChunks(startX, startZ, sizeX, sizeZ)
	for x = startX, startX + sizeX - 1 do
		for z = startZ, startZ + sizeZ - 1 do
			-- Determine biome based on position
			local distanceFromCenter = math.sqrt(x * x + z * z)
			local biome = "Environment"
			local priority = 50

			if distanceFromCenter < 3 then
				biome = "Town"
				priority = 80
			elseif distanceFromCenter < 6 then
				biome = "Forest"
				priority = 60
			elseif distanceFromCenter < 10 then
				biome = "Plains"
				priority = 50
			else
				biome = "Wilderness"
				priority = 40
			end

			table.insert(ChunkRegistry, CreateChunk(
				x, 0, z,
				{biome, "Procedural"},
				priority,
				{
					Terrain = {
						Priority = 100,
						LoadFirst = true,
						Generator = function(chunkPos, chunkSize)
							-- Procedural generation logic here
							local folder = Instance.new("Folder")
							folder.Name = "ProceduralTerrain"

							-- Create ground
							local ground = Instance.new("Part")
							ground.Size = Vector3.new(chunkSize.X, 1, chunkSize.Z)
							ground.Position = chunkPos + Vector3.new(chunkSize.X/2, 0, chunkSize.Z/2)
							ground.Anchored = true
							ground.Material = Enum.Material.Grass
							ground.Parent = folder

							return folder
						end
					}
				}
				))
		end
	end
end

-- Generate 20x20 grid of procedural chunks around spawn
-- Uncomment if you want procedural world:
-- GenerateProceduralChunks(-10, -10, 20, 20)

--============================================
-- SPECIAL CHUNKS
--============================================

-- Persistent spawn area (never unloads)
local spawnChunk = CreateChunk(
	0, 0, 0,
	{"Spawn", "Persistent"},
	100,
	{
		Terrain = {Model = nil},
		Structures = {Model = nil}
	}
)
spawnChunk.IsPersistent = true
table.insert(ChunkRegistry, spawnChunk)

-- Tutorial area
table.insert(ChunkRegistry, CreateChunk(
	-5, 0, -5,
	{"Tutorial", "Structures"},
	95,
	{
		Terrain = {Model = nil},
		Structures = {Model = nil},
		NPC = {
			RequiresActivation = true,
			Spawners = {
				{Type = "TutorialNPC", Position = {64, 0, 64}}
			}
		}
	}
	))

--============================================
-- STATISTICS
--============================================

function ChunkRegistry:GetStatistics()
	local stats = {
		TotalChunks = #ChunkRegistry,
		ByTag = {},
		ByPriority = {},
		HasLayers = 0
	}

	for _, chunk in ipairs(ChunkRegistry) do
		-- Count by tag
		for _, tag in ipairs(chunk.Tags) do
			stats.ByTag[tag] = (stats.ByTag[tag] or 0) + 1
		end

		-- Count by priority
		local priorityRange = math.floor(chunk.Priority / 10) * 10
		local rangeKey = tostring(priorityRange) .. "-" .. tostring(priorityRange + 9)
		stats.ByPriority[rangeKey] = (stats.ByPriority[rangeKey] or 0) + 1

		-- Count layers
		if chunk.Layers and next(chunk.Layers) then
			stats.HasLayers = stats.HasLayers + 1
		end
	end

	return stats
end

function ChunkRegistry:PrintStatistics()
	local stats = self:GetStatistics()

	print("=================================")
	print("CHUNK REGISTRY STATISTICS")
	print("=================================")
	print("Total Chunks:", stats.TotalChunks)
	print("Chunks with Layers:", stats.HasLayers)
	print("")
	print("By Tag:")
	for tag, count in pairs(stats.ByTag) do
		print("  " .. tag .. ":", count)
	end
	print("")
	print("By Priority Range:")
	for range, count in pairs(stats.ByPriority) do
		print("  " .. range .. ":", count)
	end
	print("=================================")
end

--============================================
-- VALIDATION
--============================================

function ChunkRegistry:Validate()
	local errors = {}

	for i, chunk in ipairs(ChunkRegistry) do
		-- Check position
		if not chunk.Position or #chunk.Position ~= 3 then
			table.insert(errors, string.format("Chunk %d: Invalid position", i))
		end

		-- Check size
		if not chunk.Size or #chunk.Size ~= 3 then
			table.insert(errors, string.format("Chunk %d: Invalid size", i))
		end

		-- Check tags
		if not chunk.Tags or type(chunk.Tags) ~= "table" then
			table.insert(errors, string.format("Chunk %d: Invalid tags", i))
		end

		-- Check priority
		if not chunk.Priority or type(chunk.Priority) ~= "number" then
			table.insert(errors, string.format("Chunk %d: Invalid priority", i))
		end
	end

	return #errors == 0, errors
end

-- Validate on load
local isValid, errors = ChunkRegistry:Validate()
if not isValid then
	warn("[ChunkRegistry] Validation errors found:")
	for _, err in ipairs(errors) do
		warn("  " .. err)
	end
end

--============================================
-- EXPORT
--============================================

print("[ChunkRegistry] Loaded", #ChunkRegistry, "chunks")
ChunkRegistry:PrintStatistics()

return ChunkRegistry