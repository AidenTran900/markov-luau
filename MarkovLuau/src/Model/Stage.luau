--!strict
--!native
--!optimize 2
local Stage = {}

export type StageList = { string }

export type Step = {
	Name: string,
	Consumes: string?,
	Produces: string?,
}

function Stage.New(names: { string }): StageList
	return names
end

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

function Stage.AssertPipeline(
	stages: StageList,
	steps: { Step }
)
	local ok, err = Stage.CheckPipeline(stages, steps)
	assert(ok, `Stage pipeline check failed: {err}`)
end

return Stage
