--[[
    CHUNK ENGINE CONFIGURATION
    Complete configuration system for custom chunk loading engine
    
    Author: TACO Custom Chunk Engine
    Version: 1.0.0
]]

local Config = {}

--============================================
-- CHUNK SYSTEM SETTINGS
--============================================

-- Basic chunk dimensions
Config.ChunkSize = Vector3.new(128, 128, 128)

-- Maximum number of chunks kept in memory
Config.MaxLoadedChunks = 50

-- Distance thresholds (in studs)
Config.LoadDistance = 512      -- Start loading chunks
Config.UnloadDistance = 768    -- Start unloading chunks
Config.ActivationDistance = 256 -- Activate chunk systems (NPC AI, etc.)

-- Performance limits
Config.MaxChunksPerFrame = 1      -- Max chunks to load per frame
Config.MaxChunksPerSecond = 5     -- Rate limiting
Config.MaxUnloadPerFrame = 2      -- Max chunks to unload per frame

-- Async loading
Config.UseAsyncLoading = true
Config.MaxConcurrentLoads = 3     -- Parallel loading tasks
Config.LoadingBudgetMs = 8        -- Max milliseconds per frame for loading

--============================================
-- LOD (LEVEL OF DETAIL) SETTINGS
--============================================

Config.LODEnabled = true
Config.LODLevels = {
	{
		Distance = 0,
		Name = "High",
		DetailLevel = 1.0,
		PhysicsEnabled = true,
		ShadowsEnabled = true,
		ParticlesEnabled = true
	},
	{
		Distance = 256,
		Name = "Medium",
		DetailLevel = 0.6,
		PhysicsEnabled = true,
		ShadowsEnabled = false,
		ParticlesEnabled = false
	},
	{
		Distance = 512,
		Name = "Low",
		DetailLevel = 0.3,
		PhysicsEnabled = false,
		ShadowsEnabled = false,
		ParticlesEnabled = false
	},
	{
		Distance = 768,
		Name = "VeryLow",
		DetailLevel = 0.1,
		PhysicsEnabled = false,
		ShadowsEnabled = false,
		ParticlesEnabled = false
	}
}

--============================================
-- PRIORITY SYSTEM
--============================================

Config.PriorityEnabled = true
Config.ChunkPriorities = {
	-- Higher number = higher priority
	["BossArea"] = 100,
	["Town"] = 90,
	["QuestLocation"] = 85,
	["NPC"] = 80,
	["Structures"] = 70,
	["Cave"] = 60,
	["Road"] = 50,
	["Environment"] = 40,
	["Decoration"] = 30,
	["Background"] = 10
}

-- Distance-based priority multiplier
Config.DistancePriorityMultiplier = true
Config.DistancePriorityFalloff = 0.5 -- Priority decreases with distance

--============================================
-- PRELOADING & PREDICTION
--============================================

Config.PreloadingEnabled = true
Config.PreloadDistance = 2           -- Preload chunks 2 steps ahead
Config.PredictiveLoading = true      -- Load chunks based on player movement
Config.PredictionLookahead = 3       -- Seconds to look ahead

-- Direction-based preloading weights
Config.DirectionWeights = {
	Forward = 1.0,
	ForwardLeft = 0.7,
	ForwardRight = 0.7,
	Left = 0.4,
	Right = 0.4,
	Backward = 0.2
}

--============================================
-- CULLING SETTINGS
--============================================

Config.FrustumCullingEnabled = true
Config.FrustumPadding = 30           -- Extra degrees for frustum
Config.OcclusionCullingEnabled = false -- Advanced feature (performance intensive)

--============================================
-- MULTIPLAYER SETTINGS
--============================================

Config.MultiplayerMode = true
Config.UnloadOnlyWhenEmpty = true    -- Only unload if no players in chunk
Config.PlayerCheckRadius = 64        -- Extra radius around chunk for player check
Config.SharedChunkLoading = true     -- Multiple players share chunk instances

--============================================
-- MEMORY & OPTIMIZATION
--============================================

Config.MemoryBudgetMB = 500          -- Max memory for chunks
Config.UseInstancePooling = true     -- Reuse instances
Config.PoolSize = 100                -- Instance pool size
Config.CompressChunkData = true      -- Compress serialized data

-- Garbage collection hints
Config.GCAfterUnload = true
Config.GCThreshold = 10              -- GC after X unloads

--============================================
-- PHYSICS OPTIMIZATION
--============================================

Config.PhysicsOptimization = true
Config.InactiveCollisionGroup = "ChunkInactive"
Config.ActiveCollisionGroup = "ChunkActive"

-- Collision group setup (will be created automatically)
Config.CollisionGroups = {
	ChunkInactive = {
		Collides = {"Player", "ChunkActive"}
	},
	ChunkActive = {
		Collides = {"Player", "ChunkActive", "NPC"}
	}
}

--============================================
-- ASSET PRELOADING
--============================================

Config.PreloadAssets = true
Config.AssetPreloadBudgetMs = 5      -- Max ms per frame for asset preloading
Config.AssetCacheSize = 200          -- Number of assets to cache

--============================================
-- CHUNK STORAGE
--============================================

-- Where chunks are stored when not loaded
Config.ChunkStorageLocation = game:GetService("ServerStorage"):FindFirstChild("ChunkStorage")
Config.ChunkDataFormat = "ModuleScript" -- "ModuleScript", "JSON", "Binary"

-- Chunk workspace parent
Config.ChunkParent = workspace:FindFirstChild("LoadedChunks") or workspace

--============================================
-- EVENTS & CALLBACKS
--============================================

Config.EnableEvents = true
Config.DebugEvents = false

-- Event types
Config.Events = {
	"OnChunkLoaded",
	"OnChunkUnloaded",
	"OnChunkActivated",
	"OnChunkDeactivated",
	"OnChunkLODChanged",
	"OnChunkPriorityChanged"
}

--============================================
-- DEBUG & VISUALIZATION
--============================================

Config.DebugMode = false
Config.VisualizeChunks = false       -- Show chunk boundaries
Config.VisualizeLoadRadius = false   -- Show load/unload radius
Config.ShowChunkLabels = false       -- Show chunk coordinates
Config.LogChunkOperations = false    -- Log load/unload operations
Config.PerformanceMonitoring = true  -- Track performance metrics

--============================================
-- ADVANCED FEATURES
--============================================

-- Multi-layer chunks
Config.MultiLayerEnabled = true
Config.Layers = {
	"Terrain",
	"Structures", 
	"Props",
	"NPC",
	"Lighting",
	"Effects"
}

-- Layer-specific settings
Config.LayerSettings = {
	Terrain = {
		Priority = 100,
		LoadFirst = true,
		AlwaysActive = true
	},
	Structures = {
		Priority = 90,
		LoadFirst = true,
		AlwaysActive = false
	},
	Props = {
		Priority = 70,
		LoadFirst = false,
		AlwaysActive = false
	},
	NPC = {
		Priority = 85,
		LoadFirst = false,
		AlwaysActive = false,
		RequiresActivation = true
	},
	Lighting = {
		Priority = 60,
		LoadFirst = false,
		AlwaysActive = false
	},
	Effects = {
		Priority = 50,
		LoadFirst = false,
		AlwaysActive = false
	}
}

-- Server permissions
Config.ServerSidePermissions = false
Config.PermissionCheckFunction = nil -- Custom function for permission checks

-- Animation streaming
Config.StreamAnimations = true
Config.AnimationPreloadDistance = 256

--============================================
-- SPATIAL PARTITIONING
--============================================

Config.UseSpatialHash = true
Config.SpatialHashCellSize = 64
Config.UseOctree = true
Config.OctreeMaxDepth = 6
Config.OctreeMaxObjects = 8

--============================================
-- UTILITY FUNCTIONS
--============================================

function Config:Validate()
	assert(self.ChunkSize.X > 0 and self.ChunkSize.Y > 0 and self.ChunkSize.Z > 0, "ChunkSize must be positive")
	assert(self.MaxLoadedChunks > 0, "MaxLoadedChunks must be positive")
	assert(self.LoadDistance > 0, "LoadDistance must be positive")
	assert(self.UnloadDistance > self.LoadDistance, "UnloadDistance must be greater than LoadDistance")
	assert(self.MaxChunksPerFrame > 0, "MaxChunksPerFrame must be positive")

	return true
end

function Config:GetLODLevel(distance)
	for i = #self.LODLevels, 1, -1 do
		if distance >= self.LODLevels[i].Distance then
			return self.LODLevels[i], i
		end
	end
	return self.LODLevels[1], 1
end

function Config:GetPriority(chunkTag)
	return self.ChunkPriorities[chunkTag] or self.ChunkPriorities["Environment"]
end

function Config:CalculateEffectivePriority(basePriority, distance)
	if not self.DistancePriorityMultiplier then
		return basePriority
	end

	local distanceRatio = math.clamp(distance / self.UnloadDistance, 0, 1)
	local multiplier = 1 - (distanceRatio * self.DistancePriorityFalloff)

	return basePriority * multiplier
end

-- Initialize
Config:Validate()

return Config