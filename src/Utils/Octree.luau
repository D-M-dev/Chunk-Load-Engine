--[[
    OCTREE IMPLEMENTATION
    Spatial partitioning for efficient chunk queries
    
    Author: TACO Custom Chunk Engine
    Version: 1.0.0
]]

local Octree = {}
Octree.__index = Octree

--============================================
-- OCTREE NODE
--============================================

local OctreeNode = {}
OctreeNode.__index = OctreeNode

function OctreeNode.new(bounds, depth, maxDepth, maxObjects)
	local self = setmetatable({}, OctreeNode)

	self.Bounds = bounds -- {Min = Vector3, Max = Vector3, Center = Vector3}
	self.Depth = depth
	self.MaxDepth = maxDepth
	self.MaxObjects = maxObjects

	self.Objects = {}
	self.Children = nil
	self.IsLeaf = true

	return self
end

function OctreeNode:GetSize()
	return self.Bounds.Max - self.Bounds.Min
end

function OctreeNode:ContainsPoint(point)
	return point.X >= self.Bounds.Min.X and point.X <= self.Bounds.Max.X and
		point.Y >= self.Bounds.Min.Y and point.Y <= self.Bounds.Max.Y and
		point.Z >= self.Bounds.Min.Z and point.Z <= self.Bounds.Max.Z
end

function OctreeNode:IntersectsSphere(center, radius)
	-- Find closest point in bounds to sphere center
	local closestX = math.clamp(center.X, self.Bounds.Min.X, self.Bounds.Max.X)
	local closestY = math.clamp(center.Y, self.Bounds.Min.Y, self.Bounds.Max.Y)
	local closestZ = math.clamp(center.Z, self.Bounds.Min.Z, self.Bounds.Max.Z)

	local closest = Vector3.new(closestX, closestY, closestZ)
	local distance = (closest - center).Magnitude

	return distance <= radius
end

function OctreeNode:Subdivide()
	if not self.IsLeaf then
		return
	end

	self.IsLeaf = false
	self.Children = {}

	local center = self.Bounds.Center
	local min = self.Bounds.Min
	local max = self.Bounds.Max

	-- Create 8 octants
	local octants = {
		-- Bottom layer
		{Min = min, Max = center},
		{Min = Vector3.new(center.X, min.Y, min.Z), Max = Vector3.new(max.X, center.Y, center.Z)},
		{Min = Vector3.new(min.X, min.Y, center.Z), Max = Vector3.new(center.X, center.Y, max.Z)},
		{Min = Vector3.new(center.X, min.Y, center.Z), Max = Vector3.new(max.X, center.Y, max.Z)},

		-- Top layer
		{Min = Vector3.new(min.X, center.Y, min.Z), Max = Vector3.new(center.X, max.Y, center.Z)},
		{Min = Vector3.new(center.X, center.Y, min.Z), Max = Vector3.new(max.X, max.Y, center.Z)},
		{Min = Vector3.new(min.X, center.Y, center.Z), Max = Vector3.new(center.X, max.Y, max.Z)},
		{Min = center, Max = max}
	}

	for i, octant in ipairs(octants) do
		octant.Center = (octant.Min + octant.Max) / 2
		self.Children[i] = OctreeNode.new(
			octant,
			self.Depth + 1,
			self.MaxDepth,
			self.MaxObjects
		)
	end

	-- Redistribute objects to children
	local oldObjects = self.Objects
	self.Objects = {}

	for _, obj in ipairs(oldObjects) do
		self:Insert(obj)
	end
end

function OctreeNode:Insert(object)
	if not self.IsLeaf then
		-- Insert into appropriate child
		for _, child in ipairs(self.Children) do
			if child:ContainsPoint(object.Position) then
				child:Insert(object)
				return true
			end
		end
		-- If no child contains it, store in this node
		table.insert(self.Objects, object)
		return true
	end

	-- Insert into this leaf node
	table.insert(self.Objects, object)

	-- Subdivide if necessary
	if #self.Objects > self.MaxObjects and self.Depth < self.MaxDepth then
		self:Subdivide()
	end

	return true
end

function OctreeNode:Remove(object)
	if not self.IsLeaf then
		for _, child in ipairs(self.Children) do
			if child:Remove(object) then
				return true
			end
		end
	end

	local index = table.find(self.Objects, object)
	if index then
		table.remove(self.Objects, index)
		return true
	end

	return false
end

function OctreeNode:QueryRadius(center, radius, results)
	results = results or {}

	if not self:IntersectsSphere(center, radius) then
		return results
	end

	-- Check objects in this node
	for _, obj in ipairs(self.Objects) do
		local distance = (obj.Position - center).Magnitude
		if distance <= radius then
			table.insert(results, obj)
		end
	end

	-- Check children
	if not self.IsLeaf then
		for _, child in ipairs(self.Children) do
			child:QueryRadius(center, radius, results)
		end
	end

	return results
end

function OctreeNode:QueryBounds(queryBounds, results)
	results = results or {}

	-- Check if query bounds intersect this node
	if not self:BoundsIntersect(queryBounds) then
		return results
	end

	-- Check objects in this node
	for _, obj in ipairs(self.Objects) do
		if self:PointInBounds(obj.Position, queryBounds) then
			table.insert(results, obj)
		end
	end

	-- Check children
	if not self.IsLeaf then
		for _, child in ipairs(self.Children) do
			child:QueryBounds(queryBounds, results)
		end
	end

	return results
end

function OctreeNode:BoundsIntersect(other)
	return not (
		self.Bounds.Max.X < other.Min.X or self.Bounds.Min.X > other.Max.X or
			self.Bounds.Max.Y < other.Min.Y or self.Bounds.Min.Y > other.Max.Y or
			self.Bounds.Max.Z < other.Min.Z or self.Bounds.Min.Z > other.Max.Z
	)
end

function OctreeNode:PointInBounds(point, bounds)
	return point.X >= bounds.Min.X and point.X <= bounds.Max.X and
		point.Y >= bounds.Min.Y and point.Y <= bounds.Max.Y and
		point.Z >= bounds.Min.Z and point.Z <= bounds.Max.Z
end

function OctreeNode:Clear()
	self.Objects = {}
	if not self.IsLeaf then
		for _, child in ipairs(self.Children) do
			child:Clear()
		end
		self.Children = nil
		self.IsLeaf = true
	end
end

function OctreeNode:GetTotalObjects()
	local count = #self.Objects
	if not self.IsLeaf then
		for _, child in ipairs(self.Children) do
			count = count + child:GetTotalObjects()
		end
	end
	return count
end

--============================================
-- OCTREE MAIN
--============================================

function Octree.new(bounds, maxDepth, maxObjects)
	local self = setmetatable({}, Octree)

	maxDepth = maxDepth or 6
	maxObjects = maxObjects or 8

	-- Ensure bounds has Center
	if not bounds.Center then
		bounds.Center = (bounds.Min + bounds.Max) / 2
	end

	self.Root = OctreeNode.new(bounds, 0, maxDepth, maxObjects)
	self.ObjectMap = {} -- For quick lookups

	return self
end

function Octree:Insert(object)
	assert(object.Position, "Object must have Position property")

	local success = self.Root:Insert(object)
	if success then
		self.ObjectMap[object] = true
	end
	return success
end

function Octree:Remove(object)
	local success = self.Root:Remove(object)
	if success then
		self.ObjectMap[object] = nil
	end
	return success
end

function Octree:Update(object, newPosition)
	if not self.ObjectMap[object] then
		return false
	end

	self:Remove(object)
	object.Position = newPosition
	return self:Insert(object)
end

function Octree:QueryRadius(center, radius)
	return self.Root:QueryRadius(center, radius, {})
end

function Octree:QueryBounds(bounds)
	return self.Root:QueryBounds(bounds, {})
end

function Octree:GetNearest(position, maxDistance)
	maxDistance = maxDistance or math.huge

	local candidates = self:QueryRadius(position, maxDistance)

	local nearest = nil
	local nearestDistance = math.huge

	for _, obj in ipairs(candidates) do
		local distance = (obj.Position - position).Magnitude
		if distance < nearestDistance then
			nearest = obj
			nearestDistance = distance
		end
	end

	return nearest, nearestDistance
end

function Octree:GetKNearest(position, k, maxDistance)
	maxDistance = maxDistance or math.huge
	k = k or 5

	local candidates = self:QueryRadius(position, maxDistance)

	-- Calculate distances
	local withDistances = {}
	for _, obj in ipairs(candidates) do
		local distance = (obj.Position - position).Magnitude
		table.insert(withDistances, {Object = obj, Distance = distance})
	end

	-- Sort by distance
	table.sort(withDistances, function(a, b)
		return a.Distance < b.Distance
	end)

	-- Return top k
	local results = {}
	for i = 1, math.min(k, #withDistances) do
		table.insert(results, withDistances[i])
	end

	return results
end

function Octree:Clear()
	self.Root:Clear()
	self.ObjectMap = {}
end

function Octree:GetStats()
	return {
		TotalObjects = self.Root:GetTotalObjects(),
		MaxDepth = self.Root.MaxDepth,
		MaxObjects = self.Root.MaxObjects
	}
end

function Octree:Contains(object)
	return self.ObjectMap[object] == true
end

--============================================
-- VISUALIZATION (for debugging)
--============================================

function Octree:VisualizeNode(node, parent)
	if not node then
		return
	end

	-- Create visual representation
	local size = node:GetSize()
	local part = Instance.new("Part")
	part.Size = size
	part.Position = node.Bounds.Center
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 0.8
	part.Color = Color3.new(0, 1, 0)
	part.Material = Enum.Material.Neon
	part.Name = "OctreeNode_" .. node.Depth
	part.Parent = parent

	-- Visualize children
	if not node.IsLeaf then
		for _, child in ipairs(node.Children) do
			self:VisualizeNode(child, parent)
		end
	end
end

function Octree:Visualize(parent)
	parent = parent or workspace

	local folder = Instance.new("Folder")
	folder.Name = "OctreeVisualization"
	folder.Parent = parent

	self:VisualizeNode(self.Root, folder)

	return folder
end

return Octree