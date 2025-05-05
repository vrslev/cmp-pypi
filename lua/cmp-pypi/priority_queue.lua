-- [[
-- This code was taken from: https://github.com/iskolbin/lpriorityqueue
-- ]]

--[[

 PriorityQueue - v1.0.1 - public domain Lua priority queue
 implemented with indirect binary heap
 no warranty implied; use at your own risk

 based on binaryheap library (github.com/iskolbin/binaryheap)

 author: Ilya Kolbin (iskolbin@gmail.com)
 url: github.com/iskolbin/priorityqueue

 See documentation in README file.

 COMPATIBILITY

 Lua 5.1, 5.2, 5.3, LuaJIT 1, 2

 LICENSE

 This software is dual-licensed to the public domain and under the following
 license: you are granted a perpetual, irrevocable license to copy, modify,
 publish, and distribute this file as you see fit.

--]]

local floor, setmetatable = math.floor, setmetatable

local function siftup( self, from )
	local items, priorities, indices, higherpriority = self, self._priorities, self._indices, self._higherpriority
	local index = from
	local parent = floor( index / 2 )
	while index > 1 and higherpriority( priorities[index], priorities[parent] ) do
		priorities[index], priorities[parent] = priorities[parent], priorities[index]
		items[index], items[parent] = items[parent], items[index]
		indices[items[index]], indices[items[parent]] = index, parent
		index = parent
		parent = floor( index / 2 )
	end
	return index
end

local function siftdown( self, limit )
	local items, priorities, indices, higherpriority, size = self, self._priorities, self._indices, self._higherpriority, self._size
	for index = limit, 1, -1 do
		local left = index + index
		local right = left + 1
		while left <= size do
			local smaller = left
			if right <= size and higherpriority( priorities[right], priorities[left] ) then
				smaller = right
			end
			if higherpriority( priorities[smaller], priorities[index] ) then
				items[index], items[smaller] = items[smaller], items[index]
				priorities[index], priorities[smaller] = priorities[smaller], priorities[index]
				indices[items[index]], indices[items[smaller]] = index, smaller
			else
				break
			end
			index = smaller
			left = index + index
			right = left + 1
		end
	end
end

local PriorityQueueMt

local PriorityQueue = {}

local function minishigher( a, b )
	return a < b
end

local function maxishigher( a, b )
	return a > b
end

function PriorityQueue.new( priority_or_array )
	local t = type( priority_or_array )
	local higherpriority = minishigher
	
	if t == 'table' then
		higherpriority = priority_or_array.higherpriority or higherpriority
	elseif t == 'function' or t == 'string' then
		higherpriority = priority_or_array
	elseif t ~= 'nil' then
		local msg = 'Wrong argument type to PriorityQueue.new, it must be table or function or string, has: %q'
		error( msg:format( t ))
	end

	if type( higherpriority ) == 'string' then
		if higherpriority == 'min' then
			higherpriority = minishigher
		elseif higherpriority == 'max' then
			higherpriority = maxishigher
		else
			local msg = 'Wrong string argument to PriorityQueue.new, it must be "min" or "max", has: %q'
			error( msg:format( tostring( higherpriority )))
		end
	end

	local self = setmetatable( {
		_priorities = {},
		_indices = {},
		_size = 0,
		_higherpriority = higherpriority or minishigher
	}, PriorityQueueMt )

	if t == 'table' then
		self:batchenq( priority_or_array )
	end

	return self
end

function PriorityQueue:enqueue( item, priority )
	local items, priorities, indices = self, self._priorities, self._indices
	if indices[item] ~= nil then
		error( 'Item ' .. tostring(indices[item]) .. ' is already in the heap' )
	end
	local size = self._size + 1
	self._size = size	
	items[size], priorities[size], indices[item] = item, priority, size
	siftup( self, size ) 
	return self
end

function PriorityQueue:remove( item )
	local index = self._indices[item]
	if index ~= nil then
		local size = self._size
		local items, priorities, indices = self, self._priorities, self._indices
		indices[item] = nil
		if size == index then
			items[size], priorities[size] = nil, nil
			self._size = size - 1
		else
			local lastitem = items[size]
			items[index], priorities[index] = items[size], priorities[size]
			items[size], priorities[size] = nil, nil
			indices[lastitem] = index
			size = size - 1
			self._size = size
			if size > 1 then
				siftdown( self, siftup( self, index )) 
			end
		end
		return true
	else
		return false
	end
end

function PriorityQueue:contains( item )
	return self._indices[item] ~= nil
end

function PriorityQueue:update( item, priority )
	local ok = self:remove( item )
	if ok then
		self:enqueue( item, priority )
		return true
	else
		return false
	end
end

function PriorityQueue:dequeue()
	local size = self._size
	
	assert( size > 0, 'Heap is empty' )
	
	local items, priorities, indices = self, self._priorities, self._indices
	local item, priority = items[1], priorities[1]
	indices[item] = nil

	if size > 1 then
		local newitem = items[size]
		items[1], priorities[1] = newitem, priorities[size]
		items[size], priorities[size] = nil, nil
		indices[newitem] = 1
		size = size - 1
		self._size = size
		siftdown( self, 1 )
	else
		items[1], priorities[1] = nil, nil
		self._size = 0
	end

	return item, priority
end

function PriorityQueue:peek()
	return self[1], self._priorities[1]
end
	
function PriorityQueue:len()
	return self._size
end

function PriorityQueue:empty()
	return self._size <= 0
end

function PriorityQueue:batchenq( iparray )
	local items, priorities, indices = self, self._priorities, self._indices
	local size = self._size
	for i = 1, #iparray, 2 do
		local item, priority = iparray[i], iparray[i+1]
		if indices[item] ~= nil then
			error( 'Item ' .. tostring(indices[item]) .. ' is already in the heap' )
		end
		size = size + 1
		items[size], priorities[size] = item, priority
		indices[item] = size
	end
	self._size = size
	if size > 1 then
		siftdown( self, floor( size / 2 ))
	end
end

PriorityQueueMt = {
	__index = PriorityQueue,
	__len = PriorityQueue.len,
}
      
return setmetatable( PriorityQueue, {
	__call = function( _, ... )
		return PriorityQueue.new( ... )
	end
} )
