--!strict
local Author = require(script.Parent.Parent.MarkovJunior.Model.Author)
local Sample = require(script.Parent.Parent.MarkovJunior.Sample)

return function(resolver: Sample.Resolver?)
	local tileModelConfig = Author.ResolveTileModel(resolver, "Paths", {
		Rules = {
			{ In = "W", Out = "Empty" },
			{ In = "N", Out = "Empty|Line|Up|Turn|X" },
		},
	})
	
	return {
		Values = "BWN",
		Symmetry = "(xy)",
		Spec = Author.Sequence({
            -- Fill space with WFC constraints
			Author.Parallel({ Rules = { Author.Rewrite("B > N") } }),
            -- Collapse using the Paths tileset
			Author.TileModel(tileModelConfig, "BYDAWPRFUENC", {})
		})
	}
end
