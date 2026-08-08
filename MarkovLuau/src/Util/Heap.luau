--!strict
--!native
--!optimize 2

-- Binary min heap implementation

local module = {}

export type Heap<T> = {
	Items: { T },
	LessThan: (T, T) -> boolean,
}

function module.New<T>(lessThan: (T, T) -> boolean): Heap<T>
	return {
		Items = {},
		LessThan = lessThan,
	}
end

local function siftUp<T>(heap: Heap<T>, index: number)
	local items = heap.Items
	local i = index

	while i > 1 do
		local parent = i // 2
		
		if heap.LessThan(items[i], items[parent]) then
			items[i], items[parent] = items[parent], items[i]
			i = parent
		else
			break
		end
	end
end

local function siftDown<T>(heap: Heap<T>, index: number)
	local items = heap.Items
	local count = #items
	local i = index

	while true do
		local left, right = i * 2, i * 2 + 1
		local smallest = i

		if left <= count and heap.LessThan(items[left], items[smallest]) then
			smallest = left
		end
		if right <= count and heap.LessThan(items[right], items[smallest]) then
			smallest = right
		end
		if smallest == i then
			break
		end

		items[i], items[smallest] = items[smallest], items[i]
		i = smallest
	end
end

function module.Push<T>(heap: Heap<T>, item: T)
	table.insert(heap.Items, item)
	siftUp(heap, #heap.Items)
end

function module.Pop<T>(heap: Heap<T>): T?
	local items = heap.Items
	local count = #items

	if count == 0 then
		return nil
	end

	local top = items[1]
	items[1] = items[count]
	items[count] = nil

	if count > 1 then
		siftDown(heap, 1)
	end
	
	return top
end

function module.Count<T>(heap: Heap<T>): number
	return #heap.Items
end

return module
