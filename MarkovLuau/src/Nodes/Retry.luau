--!strict
--!native
--!optimize 2
local Node = require(script.Parent.Parent.Node)
local Interpreter = require(script.Parent.Parent.Interpreter)
local Contract = require(script.Parent.Parent.Model.Contract)

--[=[
	@class RetryNode
]=]
local RetryNode = {}

export type RetryData = {
	Body: Node.Node,
	Attempts: number,
	Ensures: { Contract.Check }?,
	Name: string?,
	Try: number,
	Snap: Interpreter.Snapshot?,
	AttemptRunning: boolean,
}

--[=[
	Creates a new Retry node, retrying its body upon failure to satisfy post-condition contracts.
	@param body table -- The child node body to execute.
	@param attempts number -- The maximum number of attempts before throwing an error.
	@param ensures table? -- The list of contract constraints to check after the body runs.
	@param name string? -- Optional debug name.
	@return table -- The constructed Retry node.
]=]
function RetryNode.New(
	body: Node.Node,
	attempts: number,
	ensures: { Contract.Check }?,
	name: string?
): Node.Node

	return {
		Kind = "Retry",
		Parent = nil,
		Data = {
			Body = body,
			Attempts = attempts,
			Ensures = ensures,
			Name = name,
			Try = 1,
			Snap = nil,
			AttemptRunning = false,
		} :: RetryData,
	}
end

local function startAttempt(
	data: RetryData,
	ip: Node.InterpreterState,
	dispatch: Node.Dispatch
)
	data.AttemptRunning = true

	if Node.BranchKinds[data.Body.Kind] then
		ip.Current = data.Body
	end

	dispatch[data.Body.Kind].Go(data.Body, ip, dispatch)
end

local impl: Node.NodeImpl = {
	Reset = function(node: Node.Node, dispatch: Node.Dispatch)
		local data = node.Data :: RetryData
		
		data.Try = 1
		data.Snap = nil
		data.AttemptRunning = false
		dispatch[data.Body.Kind].Reset(data.Body, dispatch)
	end,
	Go = function(node: Node.Node, ip: Node.InterpreterState, dispatch: Node.Dispatch): boolean
		local data = node.Data :: RetryData

		if data.Snap == nil then
			data.Snap = Interpreter.Snapshot(ip, data.Body)
		end

		if not data.AttemptRunning then
			data.AttemptRunning = true

			if Node.BranchKinds[data.Body.Kind] then
				ip.Current = data.Body
			end

			if dispatch[data.Body.Kind].Go(data.Body, ip, dispatch) then
				return true
			end
		end

		data.AttemptRunning = false

		local ok = true
		if data.Ensures then
			ok = Contract.CheckAll(data.Ensures, { Grid = ip.Grid })
		end

		if ok then
			ip.Current = node.Parent
			return false
		end

		data.Try += 1

		if data.Try > data.Attempts then
			error(`Retry "{data.Name or "?"}": exhausted {data.Attempts} attempts, postcondition still failing`, 0)
		end

		Interpreter.Restore(ip, dispatch, data.Body, data.Snap :: Interpreter.Snapshot)

		for _ = 1, data.Try do
			ip.Random:NextSeed()
		end

		startAttempt(data, ip, dispatch)

		return true
	end,
}
RetryNode.Impl = impl

return RetryNode
