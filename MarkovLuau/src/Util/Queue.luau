--!strict
--!native
--!optimize 2

-- Basic Queue implementation

local Queue = {}

export type Queue<T> = {
	Items: { T },
	Head: number,
}

function Queue.New<T>(): Queue<T>
	return { Items = {}, Head = 1 }
end

function Queue.Push<T>(queue: Queue<T>, item: T)
	table.insert(queue.Items, item)
end

function Queue.Pop<T>(queue: Queue<T>): T?
	if queue.Head > #queue.Items then
		return nil
	end
	local item = queue.Items[queue.Head]
	queue.Items[queue.Head] = nil
	queue.Head += 1
	return item
end

function Queue.IsEmpty<T>(queue: Queue<T>): boolean
	return queue.Head > #queue.Items
end

return Queue
