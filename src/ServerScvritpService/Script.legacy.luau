--[[
    EXAMPLE CHUNK DEFINITION
    This shows how to define a chunk with all layers and content
    
    Author: TACO Custom Chunk Engine
    Version: 1.0.0
    
    This ModuleScript should be placed in ServerStorage/ChunkStorage
    Name it with chunk coordinates, e.g., "0,0,0" or "Chunk_0_0_0"
]]

local ServerStorage = game:GetService("ServerStorage")

-- This example assumes you have template models in ServerStorage
local ChunkTemplates = ServerStorage:FindFirstChild("ChunkTemplates")

--[[
    CHUNK DATA STRUCTURE:
    
    A chunk definition contains:
    - Position information (handled by filename/coordinates)
    - Tags for categorization
    - Priority for loading order
    - Layers with actual content
    - Metadata
]]

local chunk = {
	-- Metadata
	Tags = {"Town", "Structures", "NPC"},
	Priority = 90, -- High priority for town
	IsPersistent = false, -- Can be unloaded

	-- Multi-layer content
	Layers = {
		-- TERRAIN LAYER
		-- Base terrain, ground, roads
		Terrain = {
			Priority = 100,
			LoadFirst = true,

			-- Method 1: Reference to existing model
			Model = ChunkTemplates and ChunkTemplates:FindFirstChild("Town_Terrain"),

			-- Method 2: Procedurally generated content
			Generator = function(chunkPosition, chunkSize)
				local folder = Instance.new("Folder")
				folder.Name = "TerrainLayer"

				-- Create ground plane
				local ground = Instance.new("Part")
				ground.Name = "Ground"
				ground.Size = Vector3.new(chunkSize.X, 1, chunkSize.Z)
				ground.Position = chunkPosition + Vector3.new(chunkSize.X/2, 0, chunkSize.Z/2)
				ground.Anchored = true
				ground.Material = Enum.Material.Grass
				ground.Color = Color3.fromRGB(106, 127, 45)
				ground.Parent = folder

				-- Add road
				local road = Instance.new("Part")
				road.Name = "Road"
				road.Size = Vector3.new(chunkSize.X, 0.5, 20)
				road.Position = chunkPosition + Vector3.new(chunkSize.X/2, 0.5, chunkSize.Z/2)
				road.Anchored = true
				road.Material = Enum.Material.Asphalt
				road.Color = Color3.fromRGB(50, 50, 50)
				road.Parent = folder

				return folder
			end
		},

		-- STRUCTURES LAYER
		-- Buildings, walls, large objects
		Structures = {
			Priority = 90,
			LoadFirst = true,

			Model = ChunkTemplates and ChunkTemplates:FindFirstChild("Town_Buildings"),

			-- Alternative: Define structures procedurally
			Objects = {
				{
					Type = "Building",
					Position = Vector3.new(20, 0, 20),
					Template = "TownHouse01",
					Scale = 1.0,
					Rotation = 0
				},
				{
					Type = "Building",
					Position = Vector3.new(60, 0, 20),
					Template = "TownHouse02",
					Scale = 1.0,
					Rotation = 90
				},
				{
					Type = "Building",
					Position = Vector3.new(100, 0, 20),
					Template = "Shop01",
					Scale = 1.2,
					Rotation = 0
				}
			}
		},

		-- PROPS LAYER
		-- Smaller decorative objects
		Props = {
			Priority = 70,
			LoadFirst = false,

			Model = ChunkTemplates and ChunkTemplates:FindFirstChild("Town_Props"),

			Objects = {
				{Type = "StreetLight", Position = Vector3.new(10, 0, 10)},
				{Type = "Bench", Position = Vector3.new(15, 0, 15), Rotation = 45},
				{Type = "Tree", Position = Vector3.new(25, 0, 5), Scale = 1.5},
				{Type = "Tree", Position = Vector3.new(30, 0, 8), Scale = 1.2},
				{Type = "Barrel", Position = Vector3.new(50, 0, 50)},
				{Type = "Crate", Position = Vector3.new(52, 0, 50)},
			}
		},

		-- NPC LAYER
		-- NPC spawn points and AI
		NPC = {
			Priority = 85,
			LoadFirst = false,
			RequiresActivation = true, -- Only spawn when chunk is active

			Spawners = {
				{
					Type = "Villager",
					Position = Vector3.new(30, 0, 30),
					Wander = true,
					WanderRadius = 20,
					DialogueEnabled = true,
					Name = "John the Blacksmith"
				},
				{
					Type = "Merchant",
					Position = Vector3.new(100, 0, 25),
					Wander = false,
					ShopEnabled = true,
					Name = "Sarah the Trader"
				},
				{
					Type = "Guard",
					Position = Vector3.new(10, 0, 10),
					Patrol = true,
					PatrolPoints = {
						Vector3.new(10, 0, 10),
						Vector3.new(10, 0, 50),
						Vector3.new(50, 0, 50),
						Vector3.new(50, 0, 10)
					}
				}
			}
		},

		-- LIGHTING LAYER
		-- Lights, effects, atmosphere
		Lighting = {
			Priority = 60,
			LoadFirst = false,

			Lights = {
				{
					Type = "StreetLight",
					Position = Vector3.new(10, 8, 10),
					Color = Color3.fromRGB(255, 200, 100),
					Brightness = 2,
					Range = 30
				},
				{
					Type = "StreetLight",
					Position = Vector3.new(10, 8, 50),
					Color = Color3.fromRGB(255, 200, 100),
					Brightness = 2,
					Range = 30
				}
			}
		},

		-- EFFECTS LAYER
		-- Particles, sounds, ambiance
		Effects = {
			Priority = 50,
			LoadFirst = false,

			Particles = {
				{
					Type = "Smoke",
					Position = Vector3.new(20, 10, 20), -- Chimney
					Rate = 5,
					Color = Color3.fromRGB(100, 100, 100)
				}
			},

			Sounds = {
				{
					Type = "Ambient",
					Position = Vector3.new(64, 0, 64), -- Center
					SoundId = "rbxassetid://123456789", -- Replace with actual sound
					Volume = 0.3,
					Looped = true
				}
			}
		}
	}
}

--[[
    ALTERNATIVE: Simplified single-layer format
    If you don't need multi-layer, you can use this simpler format:
]]
local simplifiedChunk = {
	Tags = {"Environment"},
	Priority = 50,

	-- Direct model reference
	Model = ChunkTemplates and ChunkTemplates:FindFirstChild("SimpleChunk"),

	-- Or procedural generation
	Generate = function(position, size)
		local model = Instance.new("Model")
		model.Name = "ChunkContent"

		-- Add your content here
		-- ...

		return model
	end
}

--[[
    EMPTY CHUNK TEMPLATE
    Use this as a starting point for new chunks
]]
local emptyChunk = {
	Tags = {},
	Priority = 50,
	IsPersistent = false,

	Layers = {
		Terrain = {
			Priority = 100,
			LoadFirst = true,
			Model = nil -- Add your model reference
		},

		Structures = {
			Priority = 90,
			LoadFirst = true,
			Model = nil
		},

		Props = {
			Priority = 70,
			LoadFirst = false,
			Model = nil
		},

		NPC = {
			Priority = 85,
			LoadFirst = false,
			RequiresActivation = true,
			Spawners = {}
		},

		Lighting = {
			Priority = 60,
			LoadFirst = false,
			Lights = {}
		},

		Effects = {
			Priority = 50,
			LoadFirst = false,
			Particles = {},
			Sounds = {}
		}
	}
}

-- Return the chunk definition
return chunk

--[[
    USAGE NOTES:
    
    1. Place this ModuleScript in ServerStorage/ChunkStorage
    2. Name it with chunk coordinates (e.g., "0,0,0")
    3. The ChunkManager will automatically load it
    
    4. For model references:
       - Store template models in ServerStorage/ChunkTemplates
       - Reference them in the Layer.Model field
       - The engine will clone them when loading
    
    5. For procedural generation:
       - Implement the Generator function
       - It receives chunkPosition and chunkSize
       - Return a Model or Folder containing the content
    
    6. Tags are used for:
       - Priority calculation
       - Filtering (e.g., load all "Town" chunks first)
       - Gameplay logic (e.g., entering "Cave" area)
    
    7. Layer system benefits:
       - Load layers independently
       - Different LOD per layer
       - Easier to manage complex chunks
       - Better performance (load critical layers first)
    
    8. NPC layer:
       - Spawners only activate when chunk is active
       - Reduces AI overhead for distant chunks
       - Can include patrol routes, dialogue, etc.
]]