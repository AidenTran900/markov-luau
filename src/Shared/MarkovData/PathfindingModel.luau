--!strict
local Author = require(script.Parent.Parent.MarkovJunior.Model.Author)
local Sample = require(script.Parent.Parent.MarkovJunior.Sample)

return function(resolver: Sample.Resolver?)
	return {
		Values = "BWARP",
		Spec = Author.Sequence({
			-- Seed starting and ending points
			Author.Parallel({
				Rules = { Author.Rewrite("B > A", { P = 0.001 }) },
				Steps = 1
			}),
			Author.Parallel({
				Rules = { Author.Rewrite("B > R", { P = 0.001 }) },
				Steps = 1
			}),
			-- Trace path
			Author.Path({
				From = "A",
				To = "R",
				On = "B",
				Color = "P"
			})
		})
	}
end
