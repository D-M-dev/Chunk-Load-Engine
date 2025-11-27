--[[
    CHUNK MANAGER
    Core chunk loading and management system
    
    Author: TACO Custom Chunk Engine
    Version: 1.0.0
    
    Features:
    - Dynamic chunk streaming based on player position
    - LOD system
    - Priority-based loading
    - Frustum culling
    - Predictive preloading
    - Multiplayer support
    - Event system
    - Performance optimization
]]

local ChunkManager = {}
ChunkManager.__index = ChunkManager

-- Dependencies
local Config = require(script.Parent.Config)
local ChunkData = require(script.Parent.ChunkData)
local LODSystem = require(script.Parent.LODSystem)
local Octree = require(script.Parent.Utils.Octree)

-- Services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

--============================================
-- CONSTRUCTOR
--============================================

function ChunkManager.new(config)
	local self = setmetatable({}, ChunkManager)

	-- Configuration
	self.Config = config or Config

	-- Chunk storage
	self.Chunks = {} -- All registered chunks
	self.LoadedChunks = {} -- Currently loaded chunks
	self.ActiveChunks = {} -- Currently active chunks (with AI, physics, etc.)
	self.ChunkMap = {} -- Coordinate-based lookup

	-- Spatial indexing
	self:InitializeSpatialIndex()

	-- Systems
	self.LODSystem = LODSystem.new(self.Config)

	-- Player tracking
	self.TrackedPlayers = {}

	-- Loading queue
	self.LoadQueue = {}
	self.UnloadQueue = {}
	self.LoadingChunks = {} -- Currently being loaded

	-- Performance tracking
	self.Stats = {
		LoadedCount = 0,
		ActiveCount = 0,
		TotalLoadTime = 0,
		TotalUnloadTime = 0,
		FrameLoadCount = 0,
		LastFrameTime = 0
	}

	-- Events
	self.Events = self:CreateEventSystem()

	-- Update connections
	self.Connections = {}

	-- Instance pool
	self.InstancePool = {}

	-- Collision groups setup
	self:SetupCollisionGroups()

	-- State
	self.Running = false

	return self
end

--============================================
-- INITIALIZATION
--============================================

function ChunkManager:InitializeSpatialIndex()
	-- Create octree for spatial queries
	local worldSize = 10000 -- Adjust based on your world size
	local bounds = {
		Min = Vector3.new(-worldSize, -worldSize, -worldSize),
		Max = Vector3.new(worldSize, worldSize, worldSize),
		Center = Vector3.new(0, 0, 0)
	}

	self.Octree = Octree.new(
		bounds,
		self.Config.OctreeMaxDepth,
		self.Config.OctreeMaxObjects
	)
end

function ChunkManager:SetupCollisionGroups()
	if not self.Config.PhysicsOptimization then
		return
	end

	local PhysicsService = game:GetService("PhysicsService")

	-- Create collision groups - POUŽIJ NOVOU API
	for groupName, settings in pairs(self.Config.CollisionGroups) do
		local success = pcall(function()
			-- ZMĚŇ Z CreateCollisionGroup NA RegisterCollisionGroup
			PhysicsService:RegisterCollisionGroup(groupName)
		end)

		if success then
			-- Set up collisions
			for _, otherGroup in ipairs(settings.Collides) do
				pcall(function()
					PhysicsService:CollisionGroupSetCollidable(groupName, otherGroup, true)
				end)
			end
		end
	end
end

function ChunkManager:CreateEventSystem()
	local events = {}

	for _, eventName in ipairs(self.Config.Events) do
		events[eventName] = Instance.new("BindableEvent")
	end

	return events
end

--============================================
-- CHUNK REGISTRATION
--============================================

function ChunkManager:RegisterChunk(chunkData)
	assert(chunkData, "ChunkData cannot be nil")

	local key = self:GetChunkKey(chunkData.ChunkCoords)

	if self.ChunkMap[key] then
		warn("Chunk already registered at", chunkData.ChunkCoords)
		return false
	end

	-- Add to storage
	table.insert(self.Chunks, chunkData)
	self.ChunkMap[key] = chunkData

	-- Add to octree
	self.Octree:Insert(chunkData)

	if self.Config.DebugMode then
		print("[ChunkManager] Registered chunk:", chunkData)
	end

	return true
end

function ChunkManager:UnregisterChunk(chunkCoords)
	local key = self:GetChunkKey(chunkCoords)
	local chunk = self.ChunkMap[key]

	if not chunk then
		return false
	end

	-- Unload if loaded
	if chunk:IsLoaded() then
		self:UnloadChunk(chunk)
	end

	-- Remove from storage
	local index = table.find(self.Chunks, chunk)
	if index then
		table.remove(self.Chunks, index)
	end

	self.ChunkMap[key] = nil
	self.Octree:Remove(chunk)

	return true
end

function ChunkManager:GetChunkKey(coords)
	return string.format("%d,%d,%d", coords.X, coords.Y, coords.Z)
end

function ChunkManager:GetChunk(coords)
	local key = self:GetChunkKey(coords)
	return self.ChunkMap[key]
end

--============================================
-- CHUNK LOADING
--============================================

function ChunkManager:LoadChunk(chunk)
	if chunk:IsLoaded() or chunk.State == ChunkData.State.LOADING then
		return false
	end

	-- Check if we're at max loaded chunks
	if #self.LoadedChunks >= self.Config.MaxLoadedChunks then
		if self.Config.DebugMode then
			print("[ChunkManager] Max chunks reached, deferring load")
		end
		return false
	end

	chunk:SetState(ChunkData.State.LOADING)
	self.LoadingChunks[chunk] = true

	local startTime = os.clock()

	-- Use async loading if enabled
	if self.Config.UseAsyncLoading then
		task.spawn(function()
			self:LoadChunkAsync(chunk, startTime)
		end)
	else
		self:LoadChunkSync(chunk, startTime)
	end

	return true
end

function ChunkManager:LoadChunkSync(chunk, startTime)
	local success, err = pcall(function()
		-- Load chunk content
		local content = self:LoadChunkContent(chunk)

		if not content then
			error("Failed to load chunk content")
		end

		-- Create instances
		chunk.ContentFolder = self:InstantiateChunkContent(chunk, content)

		-- Apply initial LOD
		local distance = self:GetClosestPlayerDistance(chunk)
		local lodConfig, lodLevel = self.Config:GetLODLevel(distance)
		self.LODSystem:ApplyLOD(chunk, lodLevel, lodConfig)

		-- Update state
		chunk:SetState(ChunkData.State.LOADED)
		table.insert(self.LoadedChunks, chunk)

		-- Track stats
		local loadTime = os.clock() - startTime
		chunk.LoadTime = loadTime
		self.Stats.TotalLoadTime = self.Stats.TotalLoadTime + loadTime
		self.Stats.LoadedCount = #self.LoadedChunks

		-- Fire event
		if self.Config.EnableEvents then
			self.Events.OnChunkLoaded:Fire(chunk)
		end

		if self.Config.LogChunkOperations then
			print(string.format(
				"[ChunkManager] Loaded %s in %.2fms",
				tostring(chunk),
				loadTime * 1000
				))
		end
	end)

	self.LoadingChunks[chunk] = nil

	if not success then
		warn("[ChunkManager] Failed to load chunk:", err)
		chunk:SetState(ChunkData.State.UNLOADED)
	end
end

function ChunkManager:LoadChunkAsync(chunk, startTime)
	task.wait() -- Yield to prevent blocking
	self:LoadChunkSync(chunk, startTime)
end

function ChunkManager:LoadChunkContent(chunk)
	if chunk.Layers and next(chunk.Layers) then
		return {Layers = chunk.Layers}
	end
	
	-- Load chunk data from storage
	-- This should be customized based on your data format

	if self.Config.ChunkDataFormat == "ModuleScript" then
		return self:LoadFromModuleScript(chunk)
	elseif self.Config.ChunkDataFormat == "JSON" then
		return self:LoadFromJSON(chunk)
	elseif self.Config.ChunkDataFormat == "Binary" then
		return self:LoadFromBinary(chunk)
	end

	return nil
end

function ChunkManager:LoadFromModuleScript(chunk)
	-- Find module in storage
	local storage = self.Config.ChunkStorageLocation
	if not storage then
		warn("[ChunkManager] Chunk storage location not found")
		return nil
	end

	local chunkModule = storage:FindFirstChild(tostring(chunk.ChunkCoords))
	if not chunkModule or not chunkModule:IsA("ModuleScript") then
		return nil
	end

	local success, data = pcall(require, chunkModule)
	return success and data or nil
end

function ChunkManager:LoadFromJSON(chunk)
	-- Implement JSON loading
	-- You would use HttpService:JSONDecode here
	warn("[ChunkManager] JSON loading not implemented yet")
	return nil
end

function ChunkManager:LoadFromBinary(chunk)
	-- Implement binary loading
	warn("[ChunkManager] Binary loading not implemented yet")
	return nil
end

--============================================
-- CHUNK INSTANTIATION
--============================================

function ChunkManager:InstantiateChunkContent(chunk, content)
	local folder = Instance.new("Folder")
	folder.Name = tostring(chunk.ChunkCoords)

	-- Multi-layer support
	if self.Config.MultiLayerEnabled and content.Layers then
		for layerName, layerData in pairs(content.Layers) do
			if chunk:HasLayer(layerName) or not self.Config.Layers then
				self:InstantiateLayer(chunk, folder, layerName, layerData)
			end
		end
	else
		-- Single layer (legacy)
		if content.Model then
			local model = content.Model:Clone()
			model.Parent = folder
			self:RegisterChunkInstances(chunk, model)
		end
	end

	folder.Parent = self.Config.ChunkParent

	return folder
end

function ChunkManager:InstantiateLayer(chunk, parent, layerName, layerData)
	local layerFolder = Instance.new("Folder")
	layerFolder.Name = layerName
	layerFolder.Parent = parent


	if layerData.Model then
		local model = layerData.Model:Clone()
		model.Parent = layerFolder
		self:RegisterChunkInstances(chunk, model)
		chunk:SetLayerLoaded(layerName, true)
	elseif layerData.Generator then

		local success, generated = pcall(function()
			return layerData.Generator(chunk.Position, chunk.Size)
		end)

		if success and generated then
			generated.Parent = layerFolder
			self:RegisterChunkInstances(chunk, generated)
			chunk:SetLayerLoaded(layerName, true)
		else
			warn("[ChunkManager] Failed to generate layer:", layerName, generated)
		end
	end
end

function ChunkManager:RegisterChunkInstances(chunk, parent)
	for _, instance in ipairs(parent:GetDescendants()) do
		chunk.InstanceCache[instance] = instance
		chunk.ObjectCount = chunk.ObjectCount + 1

		-- Tag for collection service
		if instance:IsA("BasePart") then
			CollectionService:AddTag(instance, "ChunkObject")
			CollectionService:AddTag(instance, tostring(chunk.ChunkCoords))
		end
	end
end

--============================================
-- CHUNK UNLOADING
--============================================

function ChunkManager:UnloadChunk(chunk)
	if not chunk:IsLoaded() then
		return false
	end

	if not chunk:CanUnload() then
		if self.Config.DebugMode then
			print("[ChunkManager] Cannot unload chunk:", chunk)
		end
		return false
	end

	chunk:SetState(ChunkData.State.UNLOADING)

	local startTime = os.clock()

	-- Deactivate first if active
	if chunk:IsActive() then
		self:DeactivateChunk(chunk)
	end

	-- Destroy content
	if chunk.ContentFolder then
		chunk.ContentFolder:Destroy()
	end

	-- Cleanup
	chunk:Cleanup()

	-- Remove from loaded chunks
	local index = table.find(self.LoadedChunks, chunk)
	if index then
		table.remove(self.LoadedChunks, index)
	end

	-- Update state
	chunk:SetState(ChunkData.State.UNLOADED)

	-- Track stats
	local unloadTime = os.clock() - startTime
	self.Stats.TotalUnloadTime = self.Stats.TotalUnloadTime + unloadTime
	self.Stats.LoadedCount = #self.LoadedChunks

	-- Fire event
	if self.Config.EnableEvents then
		self.Events.OnChunkUnloaded:Fire(chunk)
	end

	if self.Config.LogChunkOperations then
		print(string.format(
			"[ChunkManager] Unloaded %s in %.2fms",
			tostring(chunk),
			unloadTime * 1000
			))
	end

	-- Garbage collection hint
	if self.Config.GCAfterUnload then
		local unloadCount = 0
		for _, c in ipairs(self.LoadedChunks) do
			if c.State == ChunkData.State.UNLOADED then
				unloadCount = unloadCount + 1
			end
		end

		if unloadCount >= self.Config.GCThreshold then
			task.defer(function()
				collectgarbage("collect")
			end)
		end
	end

	return true
end

--============================================
-- CHUNK ACTIVATION/DEACTIVATION
--============================================

function ChunkManager:ActivateChunk(chunk)
	if chunk:IsActive() or not chunk:IsLoaded() then
		return false
	end

	chunk:SetState(ChunkData.State.ACTIVATING)

	-- Enable physics
	self:SetChunkPhysics(chunk, true)

	-- Spawn NPCs and entities
	self:ActivateChunkEntities(chunk)

	-- Start scripts
	self:ActivateChunkScripts(chunk)

	chunk:SetState(ChunkData.State.ACTIVE)
	table.insert(self.ActiveChunks, chunk)
	self.Stats.ActiveCount = #self.ActiveChunks

	-- Fire event
	if self.Config.EnableEvents then
		self.Events.OnChunkActivated:Fire(chunk)
	end

	return true
end

function ChunkManager:DeactivateChunk(chunk)
	if not chunk:IsActive() then
		return false
	end

	chunk:SetState(ChunkData.State.DEACTIVATING)

	-- Disable physics
	self:SetChunkPhysics(chunk, false)

	-- Deactivate entities
	self:DeactivateChunkEntities(chunk)

	-- Stop scripts
	self:DeactivateChunkScripts(chunk)

	chunk:SetState(ChunkData.State.LOADED)

	local index = table.find(self.ActiveChunks, chunk)
	if index then
		table.remove(self.ActiveChunks, index)
	end

	self.Stats.ActiveCount = #self.ActiveChunks

	-- Fire event
	if self.Config.EnableEvents then
		self.Events.OnChunkDeactivated:Fire(chunk)
	end

	return true
end

function ChunkManager:SetChunkPhysics(chunk, enabled)
	local collisionGroup = enabled and 
		self.Config.ActiveCollisionGroup or 
		self.Config.InactiveCollisionGroup

	for _, instance in pairs(chunk.InstanceCache) do
		if instance:IsA("BasePart") then
			pcall(function()
				instance.CollisionGroup = collisionGroup
			end)
		end
	end
end

function ChunkManager:ActivateChunkEntities(chunk)
	-- Find all NPC spawners and entity markers
	for _, instance in pairs(chunk.InstanceCache) do
		if CollectionService:HasTag(instance, "NPCSpawner") then
			self:SpawnNPC(instance)
		elseif CollectionService:HasTag(instance, "EntitySpawner") then
			self:SpawnEntity(instance)
		end
	end
end

function ChunkManager:DeactivateChunkEntities(chunk)
	-- Despawn NPCs and entities
	for _, instance in pairs(chunk.InstanceCache) do
		if CollectionService:HasTag(instance, "SpawnedNPC") then
			instance:Destroy()
		elseif CollectionService:HasTag(instance, "SpawnedEntity") then
			instance:Destroy()
		end
	end
end

function ChunkManager:SpawnNPC(spawner)
	-- Custom NPC spawning logic
	-- This should be implemented based on your NPC system
	if self.Config.DebugMode then
		print("[ChunkManager] Would spawn NPC at:", spawner.Position)
	end
end

function ChunkManager:SpawnEntity(spawner)
	-- Custom entity spawning logic
	if self.Config.DebugMode then
		print("[ChunkManager] Would spawn entity at:", spawner.Position)
	end
end

function ChunkManager:ActivateChunkScripts(chunk)
	for _, instance in pairs(chunk.InstanceCache) do
		if instance:IsA("Script") or instance:IsA("LocalScript") then
			if not instance:GetAttribute("CriticalScript") then
				instance.Disabled = false
			end
		end
	end
end

function ChunkManager:DeactivateChunkScripts(chunk)
	for _, instance in pairs(chunk.InstanceCache) do
		if instance:IsA("Script") or instance:IsA("LocalScript") then
			if not instance:GetAttribute("CriticalScript") then
				instance.Disabled = true
			end
		end
	end
end

--============================================
-- PLAYER TRACKING
--============================================

function ChunkManager:AddPlayer(player)
	if self.TrackedPlayers[player] then
		return false
	end

	self.TrackedPlayers[player] = {
		LastPosition = nil,
		LastVelocity = Vector3.new(0, 0, 0),
		CurrentChunk = nil,
		NearbyChunks = {}
	}

	return true
end

function ChunkManager:RemovePlayer(player)
	if not self.TrackedPlayers[player] then
		return false
	end

	-- Remove player from all chunks
	for _, chunk in ipairs(self.Chunks) do
		chunk:RemovePlayer(player)
	end

	self.TrackedPlayers[player] = nil

	return true
end

function ChunkManager:UpdatePlayerTracking(player)
	local data = self.TrackedPlayers[player]
	if not data then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	local currentPosition = rootPart.Position

	-- Calculate velocity
	if data.LastPosition then
		data.LastVelocity = (currentPosition - data.LastPosition) / self.Stats.LastFrameTime
	end

	data.LastPosition = currentPosition

	-- Update current chunk
	local chunk = self:GetChunkAtPosition(currentPosition)
	if chunk ~= data.CurrentChunk then
		if data.CurrentChunk then
			data.CurrentChunk:RemovePlayer(player)
		end
		if chunk then
			chunk:AddPlayer(player)
		end
		data.CurrentChunk = chunk
	end
end

function ChunkManager:GetChunkAtPosition(position)
	local chunkCoords = ChunkData.new(position, self.Config.ChunkSize):ChunkToWorldCoords(
		ChunkData.new(position, self.Config.ChunkSize).ChunkCoords
	)

	return self:GetChunk(ChunkData.new(position, self.Config.ChunkSize).ChunkCoords)
end

--============================================
-- STREAMING LOGIC
--============================================

function ChunkManager:UpdateStreaming()
	-- Clear frame counters
	self.Stats.FrameLoadCount = 0

	-- Update player tracking
	for player, _ in pairs(self.TrackedPlayers) do
		self:UpdatePlayerTracking(player)
	end

	-- Build priority queue
	self:BuildLoadQueue()
	self:BuildUnloadQueue()

	-- Process queues with rate limiting
	self:ProcessLoadQueue()
	self:ProcessUnloadQueue()

	-- Update LOD levels
	if self.Config.LODEnabled then
		self:UpdateLODLevels()
	end

	-- Update chunk activation
	self:UpdateChunkActivation()
end

function ChunkManager:BuildLoadQueue()
	self.LoadQueue = {}

	for player, data in pairs(self.TrackedPlayers) do
		if not data.LastPosition then
			continue
		end

		-- Query nearby chunks
		local nearbyChunks = self.Octree:QueryRadius(
			data.LastPosition,
			self.Config.LoadDistance
		)

		for _, chunk in ipairs(nearbyChunks) do
			if not chunk:IsLoaded() and chunk.State ~= ChunkData.State.LOADING then
				-- Calculate priority
				local distance = chunk:GetDistanceToPoint(data.LastPosition)
				chunk:UpdatePriority(data.LastPosition, self.Config)

				-- Add preload bonus if in movement direction
				if self.Config.PredictiveLoading then
					local directionBonus = self:CalculateDirectionPriority(
						chunk,
						data.LastPosition,
						data.LastVelocity
					)
					chunk.Priority = chunk.Priority * (1 + directionBonus)
				end

				table.insert(self.LoadQueue, chunk)
			end
		end
	end

	-- Sort by priority
	table.sort(self.LoadQueue, function(a, b)
		return a.Priority > b.Priority
	end)
end

function ChunkManager:BuildUnloadQueue()
	self.UnloadQueue = {}

	for _, chunk in ipairs(self.LoadedChunks) do
		if not chunk:CanUnload() then
			continue
		end

		-- Check distance to all players
		local shouldUnload = true
		local minDistance = math.huge

		for player, data in pairs(self.TrackedPlayers) do
			if data.LastPosition then
				local distance = chunk:GetDistanceToPoint(data.LastPosition)
				minDistance = math.min(minDistance, distance)

				if distance < self.Config.UnloadDistance then
					shouldUnload = false
					break
				end
			end
		end

		if shouldUnload then
			table.insert(self.UnloadQueue, {
				Chunk = chunk,
				Distance = minDistance
			})
		end
	end

	-- Sort by distance (farthest first)
	table.sort(self.UnloadQueue, function(a, b)
		return a.Distance > b.Distance
	end)
end

function ChunkManager:ProcessLoadQueue()
	local loadCount = 0
	local maxLoads = math.min(
		self.Config.MaxChunksPerFrame,
		self.Config.MaxLoadedChunks - #self.LoadedChunks
	)

	for _, chunk in ipairs(self.LoadQueue) do
		if loadCount >= maxLoads then
			break
		end

		if self:LoadChunk(chunk) then
			loadCount = loadCount + 1
			self.Stats.FrameLoadCount = self.Stats.FrameLoadCount + 1
		end
	end
end

function ChunkManager:ProcessUnloadQueue()
	local unloadCount = 0

	for _, entry in ipairs(self.UnloadQueue) do
		if unloadCount >= self.Config.MaxUnloadPerFrame then
			break
		end

		if self:UnloadChunk(entry.Chunk) then
			unloadCount = unloadCount + 1
		end
	end
end

function ChunkManager:UpdateLODLevels()
	-- Find closest player position for LOD calculation
	local referencePosition = nil

	for player, data in pairs(self.TrackedPlayers) do
		if data.LastPosition then
			referencePosition = data.LastPosition
			break
		end
	end

	if not referencePosition then
		return
	end

	self.LODSystem:UpdateChunkLODs(self.LoadedChunks, referencePosition)
end

function ChunkManager:UpdateChunkActivation()
	for _, chunk in ipairs(self.LoadedChunks) do
		local shouldBeActive = false

		-- Check if any player is within activation distance
		for player, data in pairs(self.TrackedPlayers) do
			if data.LastPosition then
				local distance = chunk:GetDistanceToPoint(data.LastPosition)
				if distance < self.Config.ActivationDistance then
					shouldBeActive = true
					break
				end
			end
		end

		-- Update activation state
		if shouldBeActive and not chunk:IsActive() then
			self:ActivateChunk(chunk)
		elseif not shouldBeActive and chunk:IsActive() then
			self:DeactivateChunk(chunk)
		end
	end
end

function ChunkManager:CalculateDirectionPriority(chunk, position, velocity)
	if velocity.Magnitude < 1 then
		return 0
	end

	local toChunk = (chunk:GetCenterPosition() - position).Unit
	local direction = velocity.Unit

	local dot = toChunk:Dot(direction)

	-- Map dot product to priority bonus
	return math.max(0, dot) * 0.3
end

--============================================
-- UTILITY FUNCTIONS
--============================================

function ChunkManager:GetClosestPlayerDistance(chunk)
	local minDistance = math.huge

	for player, data in pairs(self.TrackedPlayers) do
		if data.LastPosition then
			local distance = chunk:GetDistanceToPoint(data.LastPosition)
			minDistance = math.min(minDistance, distance)
		end
	end

	return minDistance
end

--============================================
-- START/STOP
--============================================

function ChunkManager:Start()
	if self.Running then
		return
	end

	self.Running = true

	-- Connect to RunService
	self.Connections.Heartbeat = RunService.Heartbeat:Connect(function(dt)
		self.Stats.LastFrameTime = dt
		self:UpdateStreaming()
	end)

	-- Track players
	for _, player in ipairs(Players:GetPlayers()) do
		self:AddPlayer(player)
	end

	self.Connections.PlayerAdded = Players.PlayerAdded:Connect(function(player)
		self:AddPlayer(player)
	end)

	self.Connections.PlayerRemoving = Players.PlayerRemoving:Connect(function(player)
		self:RemovePlayer(player)
	end)

	print("[ChunkManager] Started")
end

function ChunkManager:Stop()
	if not self.Running then
		return
	end

	self.Running = false

	-- Disconnect all
	for _, connection in pairs(self.Connections) do
		connection:Disconnect()
	end
	self.Connections = {}

	-- Unload all chunks
	for _, chunk in ipairs(self.LoadedChunks) do
		self:UnloadChunk(chunk)
	end

	print("[ChunkManager] Stopped")
end

--============================================
-- API
--============================================

function ChunkManager:ForceLoadChunk(chunkCoords)
	local chunk = self:GetChunk(chunkCoords)
	if not chunk then
		warn("[ChunkManager] Chunk not found:", chunkCoords)
		return false
	end

	return self:LoadChunk(chunk)
end

function ChunkManager:ForceUnloadChunk(chunkCoords)
	local chunk = self:GetChunk(chunkCoords)
	if not chunk then
		return false
	end

	return self:UnloadChunk(chunk)
end

function ChunkManager:GetChunkInfo(chunkCoords)
	local chunk = self:GetChunk(chunkCoords)
	return chunk and chunk:GetDebugInfo() or nil
end

function ChunkManager:GetStats()
	return {
		LoadedChunks = self.Stats.LoadedCount,
		ActiveChunks = self.Stats.ActiveCount,
		TotalChunks = #self.Chunks,
		AverageLoadTime = self.Stats.LoadedCount > 0 and 
			(self.Stats.TotalLoadTime / self.Stats.LoadedCount) or 0,
		TrackedPlayers = self:GetPlayerCount()
	}
end

function ChunkManager:GetPlayerCount()
	local count = 0
	for _ in pairs(self.TrackedPlayers) do
		count = count + 1
	end
	return count
end

--============================================
-- CLEANUP
--============================================

function ChunkManager:Cleanup()
	self:Stop()

	-- Cleanup systems
	self.LODSystem:Cleanup()
	self.Octree:Clear()

	-- Cleanup events
	for _, event in pairs(self.Events) do
		event:Destroy()
	end

	-- Clear data
	self.Chunks = {}
	self.LoadedChunks = {}
	self.ActiveChunks = {}
	self.ChunkMap = {}
	self.TrackedPlayers = {}

	print("[ChunkManager] Cleaned up")
end

return ChunkManager