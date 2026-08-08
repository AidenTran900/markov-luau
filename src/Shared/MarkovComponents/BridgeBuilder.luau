--!strict
-- A global backtracking search that attempts to draw bridges between start and goal markers over open gaps
local Component = require(script.Parent.Parent.MarkovJunior.Model.Component)
local Author = require(script.Parent.Parent.MarkovJunior.Model.Author)

export type Bindings = {
	Start: string, -- Start marker (SeaVilla: "S")
	Goal: string, -- Goal marker (SeaVilla: "Y")
	Bridge: string, -- The bridge surface (SeaVilla: "B")
	Support: string, -- The pillar supporting the bridge (SeaVilla: "h")
	Solid: string, -- Solid ground (SeaVilla: "B")
	Empty: string, -- Empty space/water to cross (SeaVilla: "a")
	FailMarker: string, -- Temporary marker for failed paths (SeaVilla: "r")
	Water: string, -- Water bounds (SeaVilla: "A")
}

local Inner = Component.New("BridgeBuilder", {
	Reads = {
		s = "Symbol", -- Start
		g = "Symbol", -- Goal
		b = "Symbol", -- Bridge
		h = "Symbol", -- Support
		x = "Symbol", -- Solid
		e = "Symbol", -- Empty
		f = "Symbol", -- FailMarker
		m = "Symbol", -- GoalMarker
		w = "Group", -- Water
		z = "Any",    -- Rest
	},
	Writes = {
		b = "Symbol",
		f = "Symbol",
		m = "Symbol",
		h = "Symbol",
		s = "Symbol",
		g = "Symbol",
		e = "Symbol",
	},
	Body = function(r, args)
		return {
			Author.Markov({
				-- Cancel purposeless bridge
				Author.One({ Rules = { Author.Rule(`{r.g}{r.m}/{r.x}{r.x}/*{r.x}/{r.s}{r.x}`, `*{r.f}/**/**/**`) } }),
				
				-- Connect successful bridge
				Author.One({ Rules = { Author.Rule(`{r.x}{r.g}{r.x}/{r.x}{r.m}{r.x}/{r.x}{r.x}{r.x}/{r.x}{r.s}{r.x} {r.x}{r.h}{r.x}/{r.x}{r.x}{r.x}/{r.x}{r.x}{r.x}/{r.w}{r.e}{r.w}`, `***/*{r.x}*/***/*** ***/*{r.e}*/*{r.e}*/***`) } }),
				
				-- Continue searching forward
				Author.One({
					Rules = {
						Author.Rule(`{r.x}{r.s}{r.x}/{r.x}{r.m}{r.x}/{r.x}{r.x}{r.x}/{r.x}{r.x}{r.x}/{r.x}{r.x}{r.x} *{r.e}*/{r.x}{r.x}{r.x}/{r.x}{r.x}{r.x}/{r.x}{r.x}{r.x}/{r.x}{r.x}{r.x}`, `***/*{r.x}*/***/*{r.g}*/*{r.m}* ***/*{r.e}*/*{r.e}*/*{r.h}*/***`),
						Author.Rule(`{r.x}{r.g}{r.x}/{r.x}{r.m}{r.x}/{r.x}{r.x}{r.x}/{r.x}{r.x}{r.x}/{r.x}{r.x}{r.x} *{r.h}*/{r.x}{r.x}{r.x}/{r.x}{r.x}{r.x}/{r.x}{r.x}{r.x}/{r.x}{r.x}{r.x}`, `***/*{r.x}*/***/*{r.s}*/*{r.m}* ***/*{r.e}*/*{r.e}*/*{r.e}*/***`),
					},
				}),
				
				-- Retract dead end searches
				Author.One({
					Rules = {
						Author.Rule(`{r.x}{r.x}{r.x}/{r.x}{r.x}{r.x}/{r.x}{r.g}{r.x}/{r.x}{r.f}{r.x} *{r.e}*/{r.x}{r.e}{r.x}/{r.x}{r.h}{r.x}/{r.x}{r.x}{r.x}`, `*{r.f}*/***/*{r.x}*/*{r.x}* *{r.x}*/*{r.x}*/*{r.x}*/***`),
						Author.Rule(`{r.x}{r.x}{r.x}/{r.x}{r.x}{r.x}/{r.x}{r.s}{r.x}/{r.x}{r.f}{r.x} *{r.e}*/{r.x}{r.e}{r.x}/{r.x}{r.e}{r.x}/{r.x}{r.x}{r.x}`, `*{r.f}*/***/*{r.x}*/*{r.x}* *{r.x}*/*{r.x}*/*{r.x}*/***`),
					},
				}),
				
				-- Fail state marker
				Author.One({ Rules = { Author.Rule(`{r.m}`, `{r.f}`) } }),
				
				-- Start new search
				Author.One({ Rules = { Author.Rule(`{r.x}{r.s}{r.x}/{r.x}{r.x}{r.x} {r.w}{r.e}{r.w}/{r.x}{r.x}{r.x}`, `***/*{r.m}* ***/***`) } }),
			}),
		}
	end,
})

return function(args: Bindings)
	return Inner({
		s = args.Start,
		g = args.Goal,
		b = args.Bridge,
		h = args.Support,
		x = args.Solid,
		e = args.Empty,
		f = args.FailMarker,
		m = args.GoalMarker,
		w = args.Water,
	})
end
