--[[
    PRELOAD MANAGER
    Handles efficient asset preloading for chunks
    
    Author: TACO Custom Chunk Engine
    Version: 1.0.0
]]

local PreloadManager = {}
PreloadManager.__index = PreloadManager

local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")

--============================================
-- CONSTRUCTOR
--============================================

function PreloadManager.new(config)
	local self = setmetatable({}, PreloadManager)

	self.Config = config
	self.AssetCache = {}
	self.PreloadQueue = {}
	self.PreloadedAssets = {}
	self.IsPreloading = false

	return self
end

--============================================
-- ASSET COLLECTION
--============================================

function PreloadManager:CollectAssetsFromInstance(instance, assets)
	assets = assets or {}

	-- Collect from current instance
	if instance:IsA("MeshPart") and instance.MeshId ~= "" then
		table.insert(assets, instance.MeshId)
	end

	if instance:IsA("Texture") and instance.Texture ~= "" then
		table.insert(assets, instance.Texture)
	end

	if instance:IsA("Decal") and instance.Texture ~= "" then
		table.insert(assets, instance.Texture)
	end

	if instance:IsA("Sound") and instance.SoundId ~= "" then
		table.insert(assets, instance.SoundId)
	end

	if instance:IsA("ParticleEmitter") and instance.Texture ~= "" then
		table.insert(assets, instance.Texture)
	end

	if instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
		if instance.Image ~= "" then
			table.insert(assets, instance.Image)
		end
	end

	-- Special mesh
	if instance:IsA("SpecialMesh") and instance.MeshId ~= "" then
		table.insert(assets, instance.MeshId)
		if instance.TextureId ~= "" then
			table.insert(assets, instance.TextureId)
		end
	end

	-- Animation
	if instance:IsA("Animation") and instance.AnimationId ~= "" then
		table.insert(assets, instance.AnimationId)
	end

	-- Recursively collect from children
	for _, child in ipairs(instance:GetChildren()) do
		self:CollectAssetsFromInstance(child, assets)
	end

	return assets
end

function PreloadManager:CollectAssetsFromChunk(chunk)
	local assets = {}

	if not chunk.ContentFolder then
		return assets
	end

	-- Collect from all instances in chunk
	for _, instance in pairs(chunk.InstanceCache) do
		self:CollectAssetsFromInstance(instance, assets)
	end

	-- Remove duplicates
	local uniqueAssets = {}
	local seen = {}

	for _, asset in ipairs(assets) do
		if not seen[asset] then
			seen[asset] = true
			table.insert(uniqueAssets, asset)
		end
	end

	return uniqueAssets
end

--============================================
-- PRELOADING
--============================================

function PreloadManager:PreloadAssets(assets, priority)
	priority = priority or 0

	for _, asset in ipairs(assets) do
		if not self.PreloadedAssets[asset] then
			table.insert(self.PreloadQueue, {
				Asset = asset,
				Priority = priority
			})
		end
	end

	-- Sort by priority
	table.sort(self.PreloadQueue, function(a, b)
		return a.Priority > b.Priority
	end)

	if not self.IsPreloading then
		self:StartPreloading()
	end
end

function PreloadManager:StartPreloading()
	if self.IsPreloading then
		return
	end

	self.IsPreloading = true

	task.spawn(function()
		while #self.PreloadQueue > 0 and self.IsPreloading do
			local startTime = os.clock()
			local processed = 0

			-- Process batch
			local batch = {}
			local maxBatchSize = 10

			for i = 1, math.min(maxBatchSize, #self.PreloadQueue) do
				local item = table.remove(self.PreloadQueue, 1)
				if item then
					table.insert(batch, item.Asset)
				end
			end

			if #batch > 0 then
				-- Preload batch
				local success, err = pcall(function()
					ContentProvider:PreloadAsync(batch, function(assetId, status)
						if status == Enum.AssetFetchStatus.Success then
							self.PreloadedAssets[assetId] = true
							processed = processed + 1
						end
					end)
				end)

				if not success then
					warn("[PreloadManager] Preload error:", err)
				end
			end

			local elapsed = (os.clock() - startTime) * 1000

			-- Respect budget
			if elapsed < self.Config.AssetPreloadBudgetMs then
				task.wait()
			else
				-- Budget exceeded, wait longer
				task.wait(0.1)
			end
		end

		self.IsPreloading = false
	end)
end

function PreloadManager:StopPreloading()
	self.IsPreloading = false
end

--============================================
-- CACHE MANAGEMENT
--============================================

function PreloadManager:IsAssetPreloaded(assetId)
	return self.PreloadedAssets[assetId] == true
end

function PreloadManager:GetPreloadProgress()
	local total = #self.PreloadQueue
	local preloaded = 0

	for _ in pairs(self.PreloadedAssets) do
		preloaded = preloaded + 1
	end

	return {
		Preloaded = preloaded,
		Queued = total,
		Percentage = total > 0 and (preloaded / (preloaded + total)) * 100 or 100
	}
end

function PreloadManager:ClearCache()
	-- Keep only recent assets
	if #self.PreloadedAssets > self.Config.AssetCacheSize then
		local toRemove = {}
		local count = 0

		for asset, _ in pairs(self.PreloadedAssets) do
			table.insert(toRemove, asset)
			count = count + 1

			if count >= (#self.PreloadedAssets - self.Config.AssetCacheSize) then
				break
			end
		end

		for _, asset in ipairs(toRemove) do
			self.PreloadedAssets[asset] = nil
		end
	end
end

--============================================
-- CHUNK INTEGRATION
--============================================

function PreloadManager:PreloadChunk(chunk, priority)
	if not self.Config.PreloadAssets then
		return
	end

	-- Collect assets from chunk
	local assets = self:CollectAssetsFromChunk(chunk)

	if #assets > 0 then
		self:PreloadAssets(assets, priority)

		if self.Config.DebugMode then
			print(string.format(
				"[PreloadManager] Queued %d assets for chunk %s",
				#assets,
				tostring(chunk)
				))
		end
	end
end

function PreloadManager:PreloadNearbyChunks(chunks, playerPosition)
	if not self.Config.PreloadAssets then
		return
	end

	-- Sort chunks by distance
	local sorted = {}
	for _, chunk in ipairs(chunks) do
		local distance = chunk:GetDistanceToPoint(playerPosition)
		table.insert(sorted, {
			Chunk = chunk,
			Distance = distance
		})
	end

	table.sort(sorted, function(a, b)
		return a.Distance < b.Distance
	end)

	-- Preload closest chunks first
	for i, entry in ipairs(sorted) do
		if i > 5 then break end -- Only preload 5 closest

		local priority = 100 - (i * 10) -- Closer = higher priority
		self:PreloadChunk(entry.Chunk, priority)
	end
end

--============================================
-- MANUAL PRELOAD
--============================================

function PreloadManager:PreloadAssetList(assetIds, callback)
	local progress = {
		Total = #assetIds,
		Loaded = 0,
		Failed = 0
	}

	ContentProvider:PreloadAsync(assetIds, function(assetId, status)
		if status == Enum.AssetFetchStatus.Success then
			progress.Loaded = progress.Loaded + 1
			self.PreloadedAssets[assetId] = true
		else
			progress.Failed = progress.Failed + 1
		end

		if callback then
			callback(assetId, status, progress)
		end
	end)

	return progress
end

function PreloadManager:PreloadModel(model, callback)
	local assets = self:CollectAssetsFromInstance(model)
	return self:PreloadAssetList(assets, callback)
end

--============================================
-- STATISTICS
--============================================

function PreloadManager:GetStats()
	local stats = {
		PreloadedAssets = 0,
		QueuedAssets = #self.PreloadQueue,
		IsPreloading = self.IsPreloading,
		CacheSize = 0
	}

	for _ in pairs(self.PreloadedAssets) do
		stats.PreloadedAssets = stats.PreloadedAssets + 1
	end

	stats.CacheSize = stats.PreloadedAssets

	return stats
end

--============================================
-- CLEANUP
--============================================

function PreloadManager:Cleanup()
	self:StopPreloading()
	self.PreloadQueue = {}
	self.PreloadedAssets = {}
	self.AssetCache = {}
end

return PreloadManager