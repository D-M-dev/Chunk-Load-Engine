--[[
    LOD (LEVEL OF DETAIL) SYSTEM
    Manages chunk detail levels based on distance and performance
    
    Author: TACO Custom Chunk Engine
    Version: 1.0.0
]]

local LODSystem = {}
LODSystem.__index = LODSystem

local Config = require(script.Parent.Config)

--============================================
-- CONSTRUCTOR
--============================================

function LODSystem.new(config)
	local self = setmetatable({}, LODSystem)

	self.Config = config or Config
	self.ChunkLODStates = {} -- Maps chunk to current LOD

	return self
end

--============================================
-- LOD LEVEL DETERMINATION
--============================================

function LODSystem:GetLODForDistance(distance)
	return self.Config:GetLODLevel(distance)
end

function LODSystem:ShouldChangeLOD(chunk, newLODLevel)
	local currentLOD = self.ChunkLODStates[chunk]

	if not currentLOD then
		return true, newLODLevel
	end

	-- Add hysteresis to prevent LOD flickering
	local levelDifference = math.abs(newLODLevel - currentLOD)

	return levelDifference >= 1, newLODLevel
end

--============================================
-- APPLY LOD TO CHUNK
--============================================

function LODSystem:ApplyLOD(chunk, lodLevel, lodConfig)
	local startTime = os.clock()

	if not chunk.ContentFolder then
		return false
	end

	-- Store current LOD state
	self.ChunkLODStates[chunk] = lodLevel
	chunk.CurrentLODLevel = lodLevel
	chunk.CurrentLOD = lodConfig

	-- Apply detail level
	self:ApplyDetailLevel(chunk, lodConfig)

	-- Apply physics settings
	self:ApplyPhysicsSettings(chunk, lodConfig)

	-- Apply visual settings
	self:ApplyVisualSettings(chunk, lodConfig)

	-- Apply performance settings
	self:ApplyPerformanceSettings(chunk, lodConfig)

	local endTime = os.clock()

	if self.Config.LogChunkOperations then
		print(string.format(
			"[LOD] Applied %s to chunk %s (%.2fms)",
			lodConfig.Name,
			tostring(chunk),
			(endTime - startTime) * 1000
			))
	end

	return true
end

--============================================
-- DETAIL LEVEL
--============================================

function LODSystem:ApplyDetailLevel(chunk, lodConfig)
	local detailLevel = lodConfig.DetailLevel

	for _, instance in pairs(chunk.InstanceCache) do
		if instance:IsA("Model") then
			self:ApplyDetailToModel(instance, detailLevel)
		elseif instance:IsA("BasePart") then
			self:ApplyDetailToPart(instance, detailLevel)
		end
	end
end

function LODSystem:ApplyDetailToModel(model, detailLevel)
	-- Adjust mesh detail
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("MeshPart") or descendant:IsA("SpecialMesh") then
			self:AdjustMeshDetail(descendant, detailLevel)
		elseif descendant:IsA("Texture") or descendant:IsA("Decal") then
			self:AdjustTextureDetail(descendant, detailLevel)
		end
	end
end

function LODSystem:ApplyDetailToPart(part, detailLevel)
	if part:IsA("MeshPart") then
		self:AdjustMeshDetail(part, detailLevel)
	end

	-- Adjust textures
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("Texture") or child:IsA("Decal") then
			self:AdjustTextureDetail(child, detailLevel)
		end
	end
end

function LODSystem:AdjustMeshDetail(mesh, detailLevel)
	if mesh:IsA("MeshPart") then
		-- Store original render fidelity if not already stored
		if not mesh:GetAttribute("OriginalRenderFidelity") then
			mesh:SetAttribute("OriginalRenderFidelity", mesh.RenderFidelity.Name)
		end

		-- Set LOD-appropriate fidelity
		if detailLevel >= 0.8 then
			mesh.RenderFidelity = Enum.RenderFidelity.Automatic
		elseif detailLevel >= 0.5 then
			mesh.RenderFidelity = Enum.RenderFidelity.Performance
		else
			mesh.RenderFidelity = Enum.RenderFidelity.Performance
		end
	elseif mesh:IsA("SpecialMesh") then
		-- Adjust scale for simple mesh reduction
		if not mesh:GetAttribute("OriginalScale") then
			mesh:SetAttribute("OriginalScale", tostring(mesh.Scale))
		end
	end
end

function LODSystem:AdjustTextureDetail(texture, detailLevel)
	-- Store original transparency
	if not texture:GetAttribute("OriginalTransparency") then
		texture:SetAttribute("OriginalTransparency", texture.Transparency)
	end

	-- Fade out low priority textures at low LOD
	if detailLevel < 0.3 then
		texture.Transparency = 1
	else
		local originalTransparency = texture:GetAttribute("OriginalTransparency")
		texture.Transparency = originalTransparency or 0
	end
end

--============================================
-- PHYSICS SETTINGS
--============================================

function LODSystem:ApplyPhysicsSettings(chunk, lodConfig)
	local physicsEnabled = lodConfig.PhysicsEnabled

	for _, instance in pairs(chunk.InstanceCache) do
		if instance:IsA("BasePart") then
			self:SetPartPhysics(instance, physicsEnabled)
		elseif instance:IsA("Model") then
			for _, part in ipairs(instance:GetDescendants()) do
				if part:IsA("BasePart") then
					self:SetPartPhysics(part, physicsEnabled)
				end
			end
		end
	end
end

function LODSystem:SetPartPhysics(part, enabled)
	-- Store original physics properties
	if not part:GetAttribute("OriginalCanCollide") then
		part:SetAttribute("OriginalCanCollide", part.CanCollide)
		part:SetAttribute("OriginalAnchored", part.Anchored)
	end

	if not enabled then
		part.CanCollide = false
		part.Anchored = true
	else
		local originalCanCollide = part:GetAttribute("OriginalCanCollide")
		local originalAnchored = part:GetAttribute("OriginalAnchored")

		if originalCanCollide ~= nil then
			part.CanCollide = originalCanCollide
		end
		if originalAnchored ~= nil then
			part.Anchored = originalAnchored
		end
	end
end

--============================================
-- VISUAL SETTINGS
--============================================

function LODSystem:ApplyVisualSettings(chunk, lodConfig)
	local shadowsEnabled = lodConfig.ShadowsEnabled
	local particlesEnabled = lodConfig.ParticlesEnabled

	for _, instance in pairs(chunk.InstanceCache) do
		self:ApplyVisualToInstance(instance, shadowsEnabled, particlesEnabled)
	end
end

function LODSystem:ApplyVisualToInstance(instance, shadowsEnabled, particlesEnabled)
	if instance:IsA("BasePart") then
		-- Store original cast shadow
		if not instance:GetAttribute("OriginalCastShadow") then
			instance:SetAttribute("OriginalCastShadow", instance.CastShadow)
		end

		instance.CastShadow = shadowsEnabled and instance:GetAttribute("OriginalCastShadow")
	end

	-- Handle particles
	if instance:IsA("ParticleEmitter") or instance:IsA("Beam") or instance:IsA("Trail") then
		if not instance:GetAttribute("OriginalEnabled") then
			instance:SetAttribute("OriginalEnabled", instance.Enabled)
		end

		instance.Enabled = particlesEnabled and instance:GetAttribute("OriginalEnabled")
	end

	-- Handle lights
	if instance:IsA("Light") then
		if not instance:GetAttribute("OriginalEnabled") then
			instance:SetAttribute("OriginalEnabled", instance.Enabled)
		end

		-- Lights stay enabled but reduce brightness at low LOD
		if particlesEnabled then
			instance.Enabled = instance:GetAttribute("OriginalEnabled")
		else
			instance.Enabled = false
		end
	end

	-- Recursively apply to children
	if instance:IsA("Model") then
		for _, child in ipairs(instance:GetDescendants()) do
			self:ApplyVisualToInstance(child, shadowsEnabled, particlesEnabled)
		end
	end
end

--============================================
-- PERFORMANCE SETTINGS
--============================================

function LODSystem:ApplyPerformanceSettings(chunk, lodConfig)
	-- Disable scripts at low LOD (except critical ones)
	for _, instance in pairs(chunk.InstanceCache) do
		if instance:IsA("Script") or instance:IsA("LocalScript") then
			if not instance:GetAttribute("CriticalScript") then
				instance.Disabled = lodConfig.DetailLevel < 0.5
			end
		end
	end
end

--============================================
-- RESTORE ORIGINAL SETTINGS
--============================================

function LODSystem:RestoreOriginalSettings(chunk)
	for _, instance in pairs(chunk.InstanceCache) do
		self:RestoreInstanceSettings(instance)
	end
end

function LODSystem:RestoreInstanceSettings(instance)
	-- Restore all attributes
	local attributes = {
		"OriginalRenderFidelity",
		"OriginalCanCollide",
		"OriginalAnchored",
		"OriginalCastShadow",
		"OriginalEnabled",
		"OriginalTransparency"
	}

	for _, attr in ipairs(attributes) do
		local value = instance:GetAttribute(attr)
		if value ~= nil then
			-- Apply based on property type
			if attr == "OriginalRenderFidelity" then
				if instance:IsA("MeshPart") then
					instance.RenderFidelity = Enum.RenderFidelity[value]
				end
			elseif attr == "OriginalCanCollide" then
				if instance:IsA("BasePart") then
					instance.CanCollide = value
				end
			elseif attr == "OriginalAnchored" then
				if instance:IsA("BasePart") then
					instance.Anchored = value
				end
			elseif attr == "OriginalCastShadow" then
				if instance:IsA("BasePart") then
					instance.CastShadow = value
				end
			elseif attr == "OriginalEnabled" then
				if instance:IsA("ParticleEmitter") or instance:IsA("Light") then
					instance.Enabled = value
				end
			elseif attr == "OriginalTransparency" then
				if instance:IsA("Texture") or instance:IsA("Decal") then
					instance.Transparency = value
				end
			end
		end
	end

	-- Recursively restore children
	if instance:IsA("Model") then
		for _, child in ipairs(instance:GetDescendants()) do
			self:RestoreInstanceSettings(child)
		end
	end
end

--============================================
-- BATCH LOD UPDATE
--============================================

function LODSystem:UpdateChunkLODs(chunks, playerPosition)
	local updates = {}

	for _, chunk in ipairs(chunks) do
		if chunk:IsLoaded() then
			local distance = chunk:GetDistanceToPoint(playerPosition)
			local lodConfig, lodLevel = self:GetLODForDistance(distance)

			local shouldChange, newLevel = self:ShouldChangeLOD(chunk, lodLevel)

			if shouldChange then
				table.insert(updates, {
					Chunk = chunk,
					LODLevel = newLevel,
					LODConfig = lodConfig
				})
			end
		end
	end

	-- Apply updates
	for _, update in ipairs(updates) do
		self:ApplyLOD(update.Chunk, update.LODLevel, update.LODConfig)
	end

	return #updates
end

--============================================
-- CLEANUP
--============================================

function LODSystem:Cleanup()
	self.ChunkLODStates = {}
end

--============================================
-- DEBUG
--============================================

function LODSystem:GetStats()
	local stats = {
		TrackedChunks = 0,
		LODDistribution = {}
	}

	for _, level in pairs(self.ChunkLODStates) do
		stats.TrackedChunks = stats.TrackedChunks + 1
		stats.LODDistribution[level] = (stats.LODDistribution[level] or 0) + 1
	end

	return stats
end

return LODSystem