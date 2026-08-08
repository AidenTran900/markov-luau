--!strict
--!native
--!optimize 2
local Node = require(script.Parent.Parent.Node)

local BudgetNode = {}

export type BudgetData = {
	Body: Node.Node,
	Steps: number?, -- max interpreter steps for Body, nil = unlimited
	Seconds: number?, -- max wall-clock seconds for Body, nil = unlimited
	Name: string?,
	StartCounter: number?,
	StartClock: number?,
	BodyRunning: boolean,
}

function BudgetNode.New(
	body: Node.Node,
	steps: number?,
	seconds: number?,
	name: string?
): Node.Node
	return {
		Kind = "Budget",
		Parent = nil,
		Data = {
			Body = body,
			Steps = steps,
			Seconds = seconds,
			Name = name,
			StartCounter = nil,
			StartClock = nil,
			BodyRunning = false,
		} :: BudgetData,
	}
end

local impl: Node.NodeImpl = {
	Reset = function(node: Node.Node, dispatch: Node.Dispatch)
		local data = node.Data :: BudgetData
		data.StartCounter = nil
		data.StartClock = nil
		data.BodyRunning = false
		dispatch[data.Body.Kind].Reset(data.Body, dispatch)
	end,
	Go = function(node: Node.Node, ip: Node.InterpreterState, dispatch: Node.Dispatch): boolean
		local data = node.Data :: BudgetData

		if data.StartCounter == nil then
			data.StartCounter = ip.Counter
			data.StartClock = os.clock()
		end

		if data.Steps and ip.Counter - (data.StartCounter :: number) >= data.Steps then
			error(`Budget "{data.Name or "?"}": exceeded {data.Steps} steps`, 0)
		end

		if data.Seconds and os.clock() - (data.StartClock :: number) >= data.Seconds then
			error(`Budget "{data.Name or "?"}": exceeded {data.Seconds}s`, 0)
		end

		if not data.BodyRunning then
			data.BodyRunning = true

			if Node.BranchKinds[data.Body.Kind] then
				ip.Current = data.Body
			end

			if dispatch[data.Body.Kind].Go(data.Body, ip, dispatch) then
				return true
			end
		end

		data.BodyRunning = false
		ip.Current = node.Parent

		return false
	end,
}
BudgetNode.Impl = impl

return BudgetNode
