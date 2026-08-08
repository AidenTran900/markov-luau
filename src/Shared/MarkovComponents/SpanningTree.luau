--!strict
-- A spanning tree / graph connector.
local Component = require(script.Parent.Parent.MarkovJunior.Model.Component)
local Author = require(script.Parent.Parent.MarkovJunior.Model.Author)

export type Bindings = {
	ActiveNode: string, -- Propagating state (ModernHouse: "x")
	Node: string, -- Existing node on network (ModernHouse: "s")
	Path: string, -- Existing path on network (ModernHouse: "W")
	GoalNode: string, -- Unconnected component to find (ModernHouse: "Y")
	FoundNode: string, -- Intermediate marker for found goal (ModernHouse: "n")
	DrawPath: string, -- Newly drawn path (ModernHouse: "F")
	On: string, -- Group of symbols the new path can be drawn on (ModernHouse: "aOSs")
}

local Inner = Component.New("SpanningTree", {
	Reads = {
		x = "Symbol", -- ActiveNode
		s = "Symbol", -- Node
		W = "Symbol", -- Path
		Y = "Symbol", -- GoalNode
		n = "Symbol", -- FoundNode
		F = "Symbol", -- DrawPath
		o = "Group",  -- On
		z = "Any",    -- Rest
	},
	Writes = {
		x = "Symbol",
		n = "Symbol",
	},
	Body = function(r, args)
		return {
			Author.Markov({
				Author.One({
					Rules = {
						Author.Rule(`{r.x}{r.W}{r.W}*{r.W}{r.W}{r.s}`, `******{r.x}`),
						Author.Rule(`{r.x} {r.W} {r.W} {r.s}`, `* * * {r.x}`),
						Author.Rule(`{r.s} {r.W} {r.W} {r.x}`, `{r.x} * * *`),
						Author.Rule(`{r.x}{r.W}{r.W}{r.Y}`, `***{r.n}`),
						Author.Rule(`{r.s}{r.W}{r.W}{r.n}`, `{r.x}***`),
					},
				}),
				Author.One({
					Rules = {
						Author.Rule(`{r.n}{r.F}{r.F}{r.F}{r.F}{r.F}{r.F}`, `******{r.n}`),
						Author.Rule(`{r.n}{r.F}{r.F}{r.F}{r.F}{r.F}{r.Y}`, `******{r.n}`),
					},
				}),
				Author.Path({ From = r.n, To = r.Y, On = r.o, Color = r.F, Inertia = true }),
			})
		}
	end,
})

return function(args: Bindings)
	return Inner({
		x = args.ActiveNode,
		s = args.Node,
		W = args.Path,
		Y = args.GoalNode,
		n = args.FoundNode,
		F = args.DrawPath,
		o = args.On,
	})
end
