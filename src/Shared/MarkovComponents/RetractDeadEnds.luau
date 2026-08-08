--!strict
-- Retract a path from its dead ends until it reaches a junction or endpoint
local Component = require(script.Parent.Parent.MarkovJunior.Model.Component)
local Author = require(script.Parent.Parent.MarkovJunior.Model.Author)

export type Bindings = {
	Path: string, -- the symbol of the path (e.g. "p")
	Solid: string, -- the symbol of the surrounding boundary/walls (e.g. "B")
	Empty: string, -- the symbol of the surrounding empty space (e.g. "E")
}

return Component.New("RetractDeadEnds", {
	Reads = {
		p = "Symbol",
		b = "Symbol",
		e = "Symbol",
		z = "Any",
	},
	Writes = {},
	Body = function(r, args)
		return {
			Author.All({
				Rules = {
					Author.Rule(`{r.z}{r.z}{r.z}/{r.z}{r.e}{r.p}/{r.z}{r.z}{r.z}`, `***/*{r.e}*/***`),
					Author.Rule(`{r.z}{r.z}{r.z}/{r.p}{r.e}{r.z}/{r.z}{r.z}{r.z}`, `***/*{r.e}*/***`),
					Author.Rule(`{r.z}{r.p}{r.z}/{r.z}{r.e}{r.z}/{r.z}{r.z}{r.z}`, `***/*{r.e}*/***`),
					Author.Rule(`{r.z}{r.z}{r.z}/{r.z}{r.e}{r.z}/{r.z}{r.p}{r.z}`, `***/*{r.e}*/***`),
				},
			}),
		}
	end,
})
