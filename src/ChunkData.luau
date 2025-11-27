--[[
    CHUNK DATA STRUCTURE
    Represents individual chunk data and state
    
    Author: TACO Custom Chunk Engine
    Version: 1.0.0
]]

local ChunkData = {}
ChunkData.__index = ChunkData

--============================================
-- CHUNK STATE ENUM
--============================================

ChunkData.State = {
	UNLOADED = "Unloaded",      -- Not in memory
	LOADING = "Loading",         -- Currently loading
	LOADED = "Loaded",           -- In memory but not visible
	ACTIVATING = "Activating",   -- Transitioning to active
	ACTIVE = "Active",           -- Fully active (physics, AI, etc.)
	DEACTIVATING = "Deactivating", -- Transitioning to inactive
	UNLOADING = "Unloading"      -- Being removed
}

--============================================
-- CONSTRUCTOR
--============================================

function ChunkData.new(position, chunkSize)
	local self = setmetatable({}, ChunkData)

	-- Core properties
	self.Position = position or Vector3.new(0, 0, 0)
	self.Size = chunkSize or Vector3.new(128, 128, 128)
	self.ChunkCoords = self:WorldToChunkCoords(self.Position)

	-- State
	self.State = ChunkData.State.UNLOADED
	self.LoadedTime = 0
	self.LastAccessTime = 0

	-- Tags and metadata
	self.Tags = {}
	self.Priority = 50
	self.BasePriority = 50

	-- Layer data
	self.Layers = {}
	self.LoadedLayers = {}

	-- LOD
	self.CurrentLODLevel = 1
	self.CurrentLOD = nil

	-- References
	self.ContentFolder = nil
	self.InstanceCache = {}

	-- Players tracking
	self.PlayersInChunk = {}
	self.PlayerCount = 0

	-- Neighbors (for streaming optimization)
	self.Neighbors = {}

	-- Performance metrics
	self.LoadTime = 0
	self.MemoryUsage = 0
	self.ObjectCount = 0

	-- Flags
	self.IsVisible = false
	self.IsPersistent = false
	self.RequiresActivation = false
	self.PreloadPriority = false

	return self
end

--============================================
-- COORDINATE CONVERSION
--============================================

function ChunkData:WorldToChunkCoords(worldPos)
	local chunkX = math.floor(worldPos.X / self.Size.X)
	local chunkY = math.floor(worldPos.Y / self.Size.Y)
	local chunkZ = math.floor(worldPos.Z / self.Size.Z)

	return Vector3.new(chunkX, chunkY, chunkZ)
end

function ChunkData:ChunkToWorldCoords(chunkCoords)
	return Vector3.new(
		chunkCoords.X * self.Size.X,
		chunkCoords.Y * self.Size.Y,
		chunkCoords.Z * self.Size.Z
	)
end

function ChunkData:GetCenterPosition()
	return self.Position + (self.Size / 2)
end

function ChunkData:GetBounds()
	return {
		Min = self.Position,
		Max = self.Position + self.Size,
		Center = self:GetCenterPosition()
	}
end

--============================================
-- TAG MANAGEMENT
--============================================

function ChunkData:AddTag(tag)
	if not table.find(self.Tags, tag) then
		table.insert(self.Tags, tag)
		return true
	end
	return false
end

function ChunkData:RemoveTag(tag)
	local index = table.find(self.Tags, tag)
	if index then
		table.remove(self.Tags, index)
		return true
	end
	return false
end

function ChunkData:HasTag(tag)
	return table.find(self.Tags, tag) ~= nil
end

function ChunkData:HasAnyTag(tags)
	for _, tag in ipairs(tags) do
		if self:HasTag(tag) then
			return true
		end
	end
	return false
end

--============================================
-- STATE MANAGEMENT
--============================================

function ChunkData:SetState(newState)
	local oldState = self.State
	self.State = newState

	if newState == ChunkData.State.LOADED then
		self.LoadedTime = os.clock()
	end

	self.LastAccessTime = os.clock()

	return oldState
end

function ChunkData:IsLoaded()
	return self.State == ChunkData.State.LOADED or 
		self.State == ChunkData.State.ACTIVE or
		self.State == ChunkData.State.ACTIVATING or
		self.State == ChunkData.State.DEACTIVATING
end

function ChunkData:IsActive()
	return self.State == ChunkData.State.ACTIVE
end

function ChunkData:CanUnload()
	if self.IsPersistent then
		return false
	end

	if self.PlayerCount > 0 then
		return false
	end

	if self.State == ChunkData.State.LOADING or 
		self.State == ChunkData.State.UNLOADING or
		self.State == ChunkData.State.ACTIVATING or
		self.State == ChunkData.State.DEACTIVATING then
		return false
	end

	return true
end

--============================================
-- PLAYER TRACKING
--============================================

function ChunkData:AddPlayer(player)
	if not self.PlayersInChunk[player] then
		self.PlayersInChunk[player] = true
		self.PlayerCount = self.PlayerCount + 1
		return true
	end
	return false
end

function ChunkData:RemovePlayer(player)
	if self.PlayersInChunk[player] then
		self.PlayersInChunk[player] = nil
		self.PlayerCount = self.PlayerCount - 1
		return true
	end
	return false
end

function ChunkData:HasPlayers()
	return self.PlayerCount > 0
end

function ChunkData:GetPlayers()
	local players = {}
	for player, _ in pairs(self.PlayersInChunk) do
		table.insert(players, player)
	end
	return players
end

--============================================
-- DISTANCE CALCULATIONS
--============================================

function ChunkData:GetDistanceToPoint(point)
	local center = self:GetCenterPosition()
	return (center - point).Magnitude
end

function ChunkData:GetDistanceToPlayer(player)
	local character = player.Character
	if not character then
		return math.huge
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return math.huge
	end

	return self:GetDistanceToPoint(rootPart.Position)
end

function ChunkData:IsInBounds(position)
	local bounds = self:GetBounds()
	return position.X >= bounds.Min.X and position.X <= bounds.Max.X and
		position.Y >= bounds.Min.Y and position.Y <= bounds.Max.Y and
		position.Z >= bounds.Min.Z and position.Z <= bounds.Max.Z
end

--============================================
-- LAYER MANAGEMENT
--============================================

function ChunkData:AddLayer(layerName, layerData)
	self.Layers[layerName] = layerData
end

function ChunkData:GetLayer(layerName)
	return self.Layers[layerName]
end

function ChunkData:HasLayer(layerName)
	return self.Layers[layerName] ~= nil
end

function ChunkData:IsLayerLoaded(layerName)
	return self.LoadedLayers[layerName] == true
end

function ChunkData:SetLayerLoaded(layerName, loaded)
	self.LoadedLayers[layerName] = loaded
end

--============================================
-- PRIORITY CALCULATION
--============================================

function ChunkData:UpdatePriority(playerPosition, config)
	local distance = self:GetDistanceToPoint(playerPosition)
	self.Priority = config:CalculateEffectivePriority(self.BasePriority, distance)

	-- Boost priority if players are inside
	if self.PlayerCount > 0 then
		self.Priority = self.Priority * 1.5
	end

	-- Boost priority if preload flag is set
	if self.PreloadPriority then
		self.Priority = self.Priority * 1.3
	end

	return self.Priority
end

--============================================
-- SERIALIZATION
--============================================

function ChunkData:Serialize()
	return {
		Position = {self.Position.X, self.Position.Y, self.Position.Z},
		Size = {self.Size.X, self.Size.Y, self.Size.Z},
		Tags = self.Tags,
		Priority = self.BasePriority,
		IsPersistent = self.IsPersistent,
		Layers = self.Layers
	}
end

function ChunkData.Deserialize(data, chunkSize)
	local chunk = ChunkData.new(
		Vector3.new(data.Position[1], data.Position[2], data.Position[3]),
		chunkSize or Vector3.new(data.Size[1], data.Size[2], data.Size[3])
	)

	chunk.Tags = data.Tags or {}
	chunk.BasePriority = data.Priority or 50
	chunk.Priority = chunk.BasePriority
	chunk.IsPersistent = data.IsPersistent or false
	chunk.Layers = data.Layers or {}

	return chunk
end

--============================================
-- CLEANUP
--============================================

function ChunkData:Cleanup()
	-- Clear instance cache
	for _, instance in pairs(self.InstanceCache) do
		if instance and instance.Parent then
			instance:Destroy()
		end
	end

	self.InstanceCache = {}
	self.PlayersInChunk = {}
	self.PlayerCount = 0
	self.ContentFolder = nil

	self.State = ChunkData.State.UNLOADED
end

--============================================
-- DEBUG
--============================================

function ChunkData:GetDebugInfo()
	return {
		Position = self.Position,
		ChunkCoords = self.ChunkCoords,
		State = self.State,
		Priority = self.Priority,
		Tags = self.Tags,
		PlayerCount = self.PlayerCount,
		ObjectCount = self.ObjectCount,
		MemoryUsage = self.MemoryUsage,
		LoadTime = self.LoadTime,
		IsVisible = self.IsVisible,
		CurrentLOD = self.CurrentLODLevel
	}
end

function ChunkData:__tostring()
	return string.format(
		"Chunk[%d,%d,%d] State:%s Priority:%.1f Players:%d",
		self.ChunkCoords.X,
		self.ChunkCoords.Y,
		self.ChunkCoords.Z,
		self.State,
		self.Priority,
		self.PlayerCount
	)
end

return ChunkData