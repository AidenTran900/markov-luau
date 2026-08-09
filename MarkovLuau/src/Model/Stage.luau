--!strict
--!native
--!optimize 2
--[=[
	@class Stage
	
	Manages generation pipeline stages and verifies stage dependencies.
]=]
local Stage = {}

export type StageList = { string }

export type Step = {
	Name: string,
	Consumes: string?,
	Produces: string?,
}

--[=[
	Creates a new ordered list of pipeline stage names.
	@param names table -- An array of stage names in sequential order.
	@return table -- The StageList.
]=]
function Stage.New(names: { string }): StageList
	return names
end

--[=[
	Finds the numerical index of a stage by name.
	@param stages table -- The StageList to search.
	@param name string -- The name of the stage.
	@return number? -- The 1-based index, or nil if not found.
]=]
function Stage.IndexOf(
	stages: StageList,
	name: string
): number?
	for i, n in stages do
		if n == name then
			return i
		end
	end

	return nil
end

--[=[
	Verifies that a series of steps conforms to the defined stage pipeline order.
	@param stages table -- The canonical StageList definition.
	@param steps table -- An array of Step objects representing the actual execution pipeline.
	@return boolean -- True if the pipeline is valid.
	@return string? -- Error details if invalid.
]=]
function Stage.CheckPipeline(
	stages: StageList,
	steps: { Step }): (boolean,
	string?
)
	local prevProduces: string? = nil

	for i, step in steps do
		if step.Consumes then
			assert(Stage.IndexOf(stages, step.Consumes), `Stage.CheckPipeline: unknown stage "{step.Consumes}"`)

			if i > 1 then
				if prevProduces == nil then
					return false, `step {i} ("{step.Name}") consumes "{step.Consumes}" but step {i - 1} ("{steps[i - 1].Name}") produces nothing`
				elseif prevProduces ~= step.Consumes then
					return false,
						`step {i} ("{step.Name}") consumes "{step.Consumes}" but step {i - 1} ("{steps[i - 1].Name}") produces "{prevProduces}"`
				end
			end
		end

		if step.Produces then
			assert(Stage.IndexOf(stages, step.Produces), `Stage.CheckPipeline: unknown stage "{step.Produces}"`)
		end

		prevProduces = step.Produces
	end

	return true
end

--[=[
	Asserts that a pipeline configuration is valid, throwing a Lua error if it isn't.
	@param stages table -- The canonical StageList definition.
	@param steps table -- An array of Step objects representing the actual execution pipeline.
]=]
function Stage.AssertPipeline(
	stages: StageList,
	steps: { Step }
)
	local ok, err = Stage.CheckPipeline(stages, steps)
	assert(ok, `Stage pipeline check failed: {err}`)
end

return Stage
