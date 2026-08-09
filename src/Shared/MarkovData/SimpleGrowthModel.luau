--!strict
local Author = require(script.Parent.Parent.MarkovJunior.Model.Author)
local Sample = require(script.Parent.Parent.MarkovJunior.Sample)

return function(resolver: Sample.Resolver?)
	return {
		Values = "WB",
		Spec = Author.Sequence({
            -- Seed a few starting points randomly since we do not have Origin=true
            Author.Parallel({
                Rules = { Author.Rewrite("W > B", { P = 0.005 }) },
                Steps = 1
            }),
			Author.One({
				Rules = { Author.Rule("WB", "BB") }
			})
		})
	}
end
