--!strict
-- connect two markers with a drawn path over a walkable
local Author = require(script.Parent.Parent.MarkovJunior.Model.Author)
local Loader = require(script.Parent.Parent.MarkovJunior.Model.Loader)

local Component = require(script.Parent.Parent.MarkovJunior.Model.Component)

export type Bindings = {
	From: string, -- start marker (SeaVilla: "K" / "X" / "R")
	To: string, -- end marker (SeaVilla: "k" / "G" / "r")
	On: string, -- symbol the path may be drawn across (SeaVilla: "A")
	Path: string, -- the path's own drawn color (SeaVilla: "p")
	FromMorph: string?, -- what to change the From marker into when touched by the path (defaults to Path)
	ToMorph: string?, -- what to change the To marker into when touched by the path (defaults to Path)
	Inertia: boolean?,
	Longest: boolean?,
}

local Inner = Component.New("ConnectByPath", {
	Reads = {
		f = "Symbol", -- From
		t = "Symbol", -- To
		o = "Group",  -- On
		m = "Symbol", -- FromMorph
		n = "Symbol", -- ToMorph
		z = "Any",    -- Rest
	},
	Writes = {
		p = "Symbol", -- Path
	},
	Body = function(r, args)
		local rules = {}
		
		if args.m ~= args.f then
			table.insert(rules, Author.Rule(`{r.p}{r.f}`, `*{r.m}`))
		end
		
		if args.n ~= args.t then
			table.insert(rules, Author.Rule(`{r.p}{r.t}`, `*{r.n}`))
		end
		
		return {
			Author.Markov({
				Author.One({ Rules = rules }),
				Author.Path({
					From = r.f,
					To = r.t,
					On = r.o,
					Color = r.p,
					Inertia = args.Inertia,
					Longest = args.Longest,
				}),
			}),
		}
	end,
})

return function(args: Bindings)
	local m = if args.FromMorph and args.FromMorph ~= "none" then args.FromMorph else args.From
	local n = if args.ToMorph and args.ToMorph ~= "none" then args.ToMorph else args.To
	return Inner({
		f = args.From,
		t = args.To,
		o = args.On,
		p = args.Path,
		m = m,
		n = n,
		Inertia = args.Inertia,
		Longest = args.Longest,
	})
end
