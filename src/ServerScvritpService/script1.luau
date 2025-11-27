--[[
    CHUNK STREAMER
    Main script for running the chunk loading system
    
    Place this in ServerScriptService (for server-side streaming)
    or StarterPlayerScripts (for client-side streaming)
    
    Author: TACO Custom Chunk Engine
    Version: 1.0.0
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Get engine modules
local ChunkEngine = ReplicatedStorage:WaitForChild("ChunkEngine")
local ChunkManager = require(ChunkEngine.ChunkManager)
local ChunkData = require(ChunkEngine.ChunkData)
local Config = require(ChunkEngine.Config)

--============================================
-- CONFIGURATION
--============================================

local IS_SERVER = RunService:IsServer()
local IS_CLIENT = RunService:IsClient()

-- You can override config here if needed
local customConfig = Config
-- customConfig.LoadDistance = 600
-- customConfig.DebugMode = true

--============================================
-- INITIALIZE CHUNK MANAGER
--============================================

local manager = ChunkManager.new(customConfig)

print("[Streamer] Initializing Chunk System...")
print("[Streamer] Mode:", IS_SERVER and "Server" or "Client")

--============================================
-- REGISTER CHUNKS
--============================================

--[[
    METHOD 1: Load chunks from a ChunkRegistry module
    This is the recommended approach for production
]]
local function LoadChunksFromRegistry()
	local ChunkRegistry = ChunkEngine:FindFirstChild("ChunkRegistry")

	if not ChunkRegistry or not ChunkRegistry:IsA("ModuleScript") then
		warn("[Streamer] ChunkRegistry not found, using example chunks")
		return false
	end

	local success, registry = pcall(require, ChunkRegistry)

	if not success then
		warn("[Streamer] Failed to load ChunkRegistry:", registry)
		return false
	end

	-- Register all chunks from registry
	for _, chunkDef in ipairs(registry) do
		local chunk = ChunkData.Deserialize(chunkDef, customConfig.ChunkSize)
		manager:RegisterChunk(chunk)
	end

	print("[Streamer] Registered", #registry, "chunks from registry")
	return true
end

--[[
    METHOD 2: Auto-discover chunks from workspace
    Useful for development and testing
]]
local function AutoDiscoverChunks()
	local ChunkStorage = workspace:FindFirstChild("ChunkStorage")

	if not ChunkStorage then
		warn("[Streamer] ChunkStorage folder not found in workspace")
		return false
	end

	local count = 0

	for _, folder in ipairs(ChunkStorage:GetChildren()) do
		if folder:IsA("Folder") then
			-- Parse chunk coordinates from name (e.g., "Chunk_0_0_0")
			local coords = {}
			for num in string.gmatch(folder.Name, "%-?%d+") do
				table.insert(coords, tonumber(num))
			end

			if #coords == 3 then
				local chunkCoords = Vector3.new(coords[1], coords[2], coords[3])
				local position = Vector3.new(
					chunkCoords.X * customConfig.ChunkSize.X,
					chunkCoords.Y * customConfig.ChunkSize.Y,
					chunkCoords.Z * customConfig.ChunkSize.Z
				)

				local chunk = ChunkData.new(position, customConfig.ChunkSize)

				-- Parse tags from attributes or children
				if folder:GetAttribute("Tags") then
					local tags = string.split(folder:GetAttribute("Tags"), ",")
					for _, tag in ipairs(tags) do
						chunk:AddTag(string.gsub(tag, "^%s*(.-)%s*$", "%1")) -- trim whitespace
					end
				end

				-- Set priority from attribute
				if folder:GetAttribute("Priority") then
					chunk.BasePriority = folder:GetAttribute("Priority")
					chunk.Priority = chunk.BasePriority
				end

				-- Register chunk
				manager:RegisterChunk(chunk)
				count = count + 1
			end
		end
	end

	print("[Streamer] Auto-discovered", count, "chunks")
	return count > 0
end

--[[
    METHOD 3: Programmatically generate chunks
    Useful for procedural worlds
]]
local function GenerateChunks(sizeX, sizeY, sizeZ)
	local count = 0

	for x = 0, sizeX - 1 do
		for y = 0, sizeY - 1 do
			for z = 0, sizeZ - 1 do
				local position = Vector3.new(
					x * customConfig.ChunkSize.X,
					y * customConfig.ChunkSize.Y,
					z * customConfig.ChunkSize.Z
				)

				local chunk = ChunkData.new(position, customConfig.ChunkSize)

				-- Auto-tag based on position
				if y == 0 then
					chunk:AddTag("Ground")
				elseif y > sizeY - 2 then
					chunk:AddTag("Sky")
				else
					chunk:AddTag("Environment")
				end

				-- Add some variation
				if math.random() > 0.8 then
					chunk:AddTag("Structures")
					chunk.BasePriority = 70
					chunk.Priority = 70
				end


				chunk:AddLayer("Terrain", {
					Priority = 100,
					LoadFirst = true,
					Generator = function(chunkPos, chunkSize)
						local folder = Instance.new("Folder")
						folder.Name = "ProceduralTerrain"

						-- Create ground
						local ground = Instance.new("Part")
						ground.Name = "Ground"
						ground.Size = Vector3.new(chunkSize.X, 1, chunkSize.Z)
						ground.Position = chunkPos + Vector3.new(chunkSize.X/2, 0, chunkSize.Z/2)
						ground.Anchored = true
						ground.Material = Enum.Material.Grass

						-- Random color variation
						local colorVariation = math.random(80, 120) / 100
						ground.Color = Color3.fromRGB(
							math.floor(106 * colorVariation),
							math.floor(127 * colorVariation),
							math.floor(45 * colorVariation)
						)

						ground.Parent = folder

						-- Add some random decorations
						if math.random() > 0.7 then
							local deco = Instance.new("Part")
							deco.Name = "Decoration"
							deco.Size = Vector3.new(5, 5, 5)
							deco.Position = chunkPos + Vector3.new(
								math.random(10, chunkSize.X - 10),
								2.5,
								math.random(10, chunkSize.Z - 10)
							)
							deco.Anchored = true
							deco.Material = Enum.Material.Concrete
							deco.Color = Color3.fromRGB(150, 150, 150)
							deco.Parent = folder
						end

						return folder
					end
				})

				manager:RegisterChunk(chunk)
				count = count + 1
			end
		end
	end

	print("[Streamer] Generated", count, "procedural chunks")
	return true
end

-- Try to load chunks using different methods
---local loaded = LoadChunksFromRegistry()

local loaded = false

if not loaded then
	loaded = AutoDiscoverChunks()
end

if not loaded then
	-- Fallback: generate a small test world (8x2x8 chunks)
	print("[Streamer] No chunks found, generating test world...")
	GenerateChunks(8, 2, 8)
end

--============================================
-- EVENT HANDLERS
--============================================

if customConfig.EnableEvents then
	-- OnChunkLoaded
	manager.Events.OnChunkLoaded.Event:Connect(function(chunk)
		if customConfig.DebugEvents then
			print("[Event] Chunk loaded:", chunk)
		end

		-- Custom logic when chunk loads
		-- Example: Notify players
	end)

	-- OnChunkUnloaded
	manager.Events.OnChunkUnloaded.Event:Connect(function(chunk)
		if customConfig.DebugEvents then
			print("[Event] Chunk unloaded:", chunk)
		end

		-- Custom logic when chunk unloads
	end)

	-- OnChunkActivated
	manager.Events.OnChunkActivated.Event:Connect(function(chunk)
		if customConfig.DebugEvents then
			print("[Event] Chunk activated:", chunk)
		end

		-- Custom logic when chunk becomes active
		-- Example: Start AI, enable interactivity
	end)

	-- OnChunkDeactivated
	manager.Events.OnChunkDeactivated.Event:Connect(function(chunk)
		if customConfig.DebugEvents then
			print("[Event] Chunk deactivated:", chunk)
		end

		-- Custom logic when chunk becomes inactive
	end)

	-- OnChunkLODChanged
	manager.Events.OnChunkLODChanged.Event:Connect(function(chunk, oldLOD, newLOD)
		if customConfig.DebugEvents then
			print("[Event] Chunk LOD changed:", chunk, oldLOD, "->", newLOD)
		end
	end)
end

--============================================
-- START CHUNK SYSTEM
--============================================

manager:Start()

print("[Streamer] Chunk system started!")
print("[Streamer] Total chunks registered:", #manager.Chunks)

--============================================
-- PERFORMANCE MONITORING
--============================================

if customConfig.PerformanceMonitoring then
	task.spawn(function()
		while true do
			task.wait(5) -- Log every 5 seconds

			local stats = manager:GetStats()

			print("=================================")
			print("[Performance] Chunk Statistics:")
			print("  Loaded Chunks:", stats.LoadedChunks)
			print("  Active Chunks:", stats.ActiveChunks)
			print("  Total Chunks:", stats.TotalChunks)
			print("  Tracked Players:", stats.TrackedPlayers)
			print("  Avg Load Time:", string.format("%.2fms", stats.AverageLoadTime * 1000))
			print("=================================")
		end
	end)
end

--============================================
-- DEBUG COMMANDS (Optional)
--============================================

if customConfig.DebugMode and IS_SERVER then
	-- Example: Create remote function for admin commands
	local RemoteFunction = Instance.new("RemoteFunction")
	RemoteFunction.Name = "ChunkManagerCommands"
	RemoteFunction.Parent = ReplicatedStorage

	RemoteFunction.OnServerInvoke = function(player, command, ...)
		-- Check if player is admin (implement your own check)
		local isAdmin = player:GetRankInGroup(0) >= 255 -- Example

		if not isAdmin then
			return {Success = false, Message = "Not authorized"}
		end

		if command == "stats" then
			return {Success = true, Data = manager:GetStats()}

		elseif command == "load" then
			local coords = {...}
			if #coords == 3 then
				local chunkCoords = Vector3.new(coords[1], coords[2], coords[3])
				local success = manager:ForceLoadChunk(chunkCoords)
				return {Success = success, Message = success and "Loaded" or "Failed"}
			end

		elseif command == "unload" then
			local coords = {...}
			if #coords == 3 then
				local chunkCoords = Vector3.new(coords[1], coords[2], coords[3])
				local success = manager:ForceUnloadChunk(chunkCoords)
				return {Success = success, Message = success and "Unloaded" or "Failed"}
			end

		elseif command == "info" then
			local coords = {...}
			if #coords == 3 then
				local chunkCoords = Vector3.new(coords[1], coords[2], coords[3])
				local info = manager:GetChunkInfo(chunkCoords)
				return {Success = info ~= nil, Data = info}
			end

		elseif command == "visualize" then
			-- Visualize chunk boundaries
			if customConfig.VisualizeChunks then
				customConfig.VisualizeChunks = false
				return {Success = true, Message = "Visualization disabled"}
			else
				customConfig.VisualizeChunks = true
				return {Success = true, Message = "Visualization enabled"}
			end
		end

		return {Success = false, Message = "Unknown command"}
	end
end

print("[Streamer] Debug commands enabled")


--============================================
-- VISUALIZE CHUNKS (Debug)
--============================================

if customConfig.VisualizeChunks then
	task.spawn(function()
		local VisualizationFolder = workspace:FindFirstChild("ChunkVisualization")
		if VisualizationFolder then
			VisualizationFolder:Destroy()
		end

		VisualizationFolder = Instance.new("Folder")
		VisualizationFolder.Name = "ChunkVisualization"
		VisualizationFolder.Parent = workspace

		while customConfig.VisualizeChunks do
			-- Clear old visualization
			VisualizationFolder:ClearAllChildren()

			-- Visualize loaded chunks
			for _, chunk in ipairs(manager.LoadedChunks) do
				local part = Instance.new("Part")
				part.Size = chunk.Size
				part.Position = chunk:GetCenterPosition()
				part.Anchored = true
				part.CanCollide = false
				part.Transparency = 0.8

				-- Color based on state
				if chunk:IsActive() then
					part.Color = Color3.new(0, 1, 0) -- Green for active
				else
					part.Color = Color3.new(0, 0, 1) -- Blue for loaded
				end

				part.Material = Enum.Material.Neon
				part.Name = tostring(chunk)
				part.Parent = VisualizationFolder

				-- Add label
				if customConfig.ShowChunkLabels then
					local billboard = Instance.new("BillboardGui")
					billboard.Size = UDim2.new(0, 100, 0, 50)
					billboard.Adornee = part
					billboard.AlwaysOnTop = true
					billboard.Parent = part

					local label = Instance.new("TextLabel")
					label.Size = UDim2.new(1, 0, 1, 0)
					label.BackgroundTransparency = 1
					label.Text = tostring(chunk.ChunkCoords)
					label.TextColor3 = Color3.new(1, 1, 1)
					label.TextScaled = true
					label.Parent = billboard
				end
			end

			task.wait(1)
		end

		VisualizationFolder:Destroy()
	end)
end

--============================================
-- CLEANUP ON SERVER SHUTDOWN
--============================================

game:BindToClose(function()
	print("[Streamer] Shutting down...")
	manager:Cleanup()
end)

--============================================
-- EXPOSE MANAGER (Optional)
--============================================

-- Make manager accessible to other scripts if needed
_G.ChunkManager = manager

-- Or use a ModuleScript approach:
-- return manager