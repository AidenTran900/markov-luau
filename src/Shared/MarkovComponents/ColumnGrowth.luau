--!strict
-- grows a marker one step at a time from a seed cell, through open cells, along whichever axis the two are adjacent on
local Component = require(script.Parent.Parent.MarkovJunior.Model.Component)
local Author = require(script.Parent.Parent.MarkovJunior.Model.Author)

export type Bindings = {
	Seed: string, -- symbol that seeds column growth (Apartemazements: "D")
	Open: string, -- symbol the column grows through (Apartemazements: "B")
	Column: string, -- symbol the growing column is drawn as (Apartemazements: "F")
}

local Inner = Component.New("ColumnGrowth", {
	Reads = {
		s = "Symbol",
		o = "Symbol",
		c = "Symbol",
		z = "Any",
	},
	Writes = {},
	Body = function(r, args)
		return {
			Author.All({
				Rules = {
					Author.Rule(`{r.s} {r.o}`, `* {r.c}`),
					Author.Rule(`{r.c} {r.o}`, `* {r.c}`),
				},
			}),
		}
	end,
})

return function(args: Bindings)
	return Inner({
		s = args.Seed,
		o = args.Open,
		c = args.Column,
	})
end
