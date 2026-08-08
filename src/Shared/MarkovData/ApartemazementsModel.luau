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

--================================================================
-- Symbol Mapping:
	-- B = Empty space / Exterior air
	-- W = Boundary shell (temporary constraint)
	-- N = WFC pathway constraint
	-- C = Foundation / Lower earth layer
	-- E = Upper earth layer / Grass
	-- Y = Light source / Randomization seed
	-- D = Column seed / Pillar base
	-- F = Column / Pillar body
	-- A = Solid architecture / Walls / Blocks
	-- P = Corner/Turn tile (anchors columns)
	-- R = Windows
	-- U = Marker for uneven window layouts
--================================================================

return {
	Values = "BWN",
	Symmetry = "(xy)",
	Spec = Author.Sequence({

----------------------------------------------------------------
	Author.Marker("Phase 1: Prepare Constraints"),
	-- mark bottom cells with a separate bottom color, 
	-- mark the remaining border cells (sides and top) with a separate border color
	-- Border cells should map to Empty, bottom cells should map to all tiles except Down.
----------------------------------------------------------------

	Author.Parallel({ Rules = { -- draw earth
		Author.Rewrite("B > W") 
	} 
}),

-- reset every W that isn't touching the XY boundary back to B. only the outer shell stays W
Author.Parallel({
	Rules = {
		Author.Rewrite([[
			* * * > * * *
			* * * > * * *
			* * * > * * *
			---
			* * * > * * *
			* W * > * B *
			* * * > * * *
			---
			* * * > * * *
			* * * > * * *
			* * * > * * *
		]]),
	},
}),

-- shell cells touching the interior become N (free WFC choice among pathlike tiles)
-- everything else stays W
Author.Parallel({ Rules = { -- draw earth
	Author.Rewrite([[
		B > B
		---
		W > N
	]]) 
} }),

----------------------------------------------------------------
	Author.Marker("Phase 2: Generate Stairy Cycles"),
--  Run WFC Paths tileset to generate closed stairy cycles.
----------------------------------------------------------------

Author.TileModel(tileModelConfig, "BYDAWPRFUENC", {
	Author.Parallel({ Rules = { -- draw earth
		Author.Rewrite("B > C") 
	} }),

	-- earth only survives within 2 layers of the bottom of the grid
	Author.Parallel({
		Rules = { Author.Rewrite([[
			C > B
			---
			* > *
			---
			* > *
		]]) },
	}),

	Author.Parallel({ Rules = { 
		Author.Rewrite([[
			C > E
			---
			C > N
		]]) 
	}}),
	Author.Parallel({ 
		Rules = { 
			Author.Rewrite("C > N") 
		} 
	}),

----------------------------------------------------------------
	Author.Marker("Phase 3: Randomize Light Sources"),
-- 	Randomize light sources.
----------------------------------------------------------------

	Author.Parallel({ 
		Rules = { 
			Author.Rewrite("Y > C", { P = 0.25 }) 
		}, 
		Steps = 1 
	}),
	Author.Parallel({ 
		Rules = { 
			Author.Rewrite("Y > B") 
		} 
	}),

----------------------------------------------------------------
	Author.Marker("Phase 4: Drop Columns"),
	-- Drop columns from corners of flat tiles.
----------------------------------------------------------------

	Author.All({
		Rules = {
			Author.Rewrite([[
				D > *
				---
				B > F
			]]),
			Author.Rewrite([[
				F > *
				---
				B > F
			]]),
		},
	}),

----------------------------------------------------------------
	Author.Marker("Phase 5: Retract Columns"),
--[[	Retract:
		- double columns, 
		- columns that touch ground 
		- columns that touch stairs, 
		- except columns growing from corners of the Turn tiles
]]
----------------------------------------------------------------
	
	Author.All({
		Rules = {
			Author.Rewrite([[
				F F > B B
				---
				E E > E E
			]]),
			Author.Rewrite([[
				F F > F F
				---
				F D > B D
				---
				E E > E E
			]]),
			Author.Rewrite([[
				F > B
				---
				B > B
			]]),
			Author.Rewrite([[
				B > B
				---
				F > B
			]]),
			Author.Rewrite([[
				F > B
				---
				P > P
			]]),
			Author.Rewrite([[
				P * > * *
				---
				* F > * B
			]]),
		},
	}),

	Author.All({
		Rules = {
			-- draw corner columns
			Author.Rewrite([[
				* A * > * * *
				A D B > * * *
				* B * > * * *
				---
				* * * > * * *
				* B * > * F *
				* * * > * * *
			]]),
			-- forget structure
			Author.Rewrite([[
				F > F
				---
				B > F
			]]),
		},
	}),

----------------------------------------------------------------
	Author.Marker("Phase 6: Grow Windows"),
-- 	Grow windows between neighboring columns.
----------------------------------------------------------------

	Author.All({
		Rules = {
			Author.Rewrite([[
				F B B B F > * R R R *
				---
				* A A A * > * * * * *
			]]),
			Author.Rewrite([[
				F B B B F > * R R R *
				---
				* R R R * > * * * * *
			]]),
		},
	}),

----------------------------------------------------------------
--	Phase 7: Merge Windows
-- 	Merge windows into bigger rectangles
----------------------------------------------------------------
	
	----------------------------------------------------------------
	Author.Marker("Step 7a: Detect Uneven Patterns"),
	-- Detect uneven patterns of windows when window corners touch window midpoints.
	----------------------------------------------------------------

	Author.Parallel({
		Rules = {
			Author.Rewrite([[
				R F F R > U * * U
				---
				R F D A > U * * *
			]]),
			Author.Rewrite([[
				R F D A > U * * *
				---
				R F F R > U * * U
			]]),
		},
	}),

	----------------------------------------------------------------
	Author.Marker("Step 7b: Propagate Markings"),
	-- Mark these patterns and propagate the markings through the whole lengths of window sides.
	----------------------------------------------------------------

	Author.All({
		Rules = {
			Author.Rewrite([[
				R > U
				---
				U > *
			]]),
			-- forget structure
			Author.Rewrite([[
				U > *
				---
				R > U
			]]),
		},
	}),

	----------------------------------------------------------------
	Author.Marker("Step 7c: Merge Unmarked Pairs"),
	--	Merge unmarked pairs of window sides
	----------------------------------------------------------------

	Author.Parallel({ Rules = { Author.Rewrite([[
		R F F R > * R R *
		B B B B > * * * *
	]]) } }),
	Author.Parallel({ Rules = { -- forget structure
		Author.Rewrite("U > R") 
	} }),

	Author.Parallel({
		Rules = {
			Author.Rewrite([[
				R R > U U
				---
				D A > * *
				---
				F R > * U
			]]),
			Author.Rewrite([[
				F R > * U
				---
				D A > * *
				---
				R R > U U
			]]),
		},
	}),

	Author.All({
		Rules = {
			-- mark v uneven windows
			Author.Rewrite("R U > U *"),
			-- mark v uneven windows
			Author.Rewrite("U R > * U"),
		},
	}),

	Author.Parallel({
		Rules = {
			-- merge v even windows
			Author.Rewrite([[
				R B > R B
				---
				A B > R B
				---
				R B > R B
			]]),
			Author.Rewrite([[
				R B > R B
				---
				D B > R B
				---
				R B > R B
			]]),
		},
	}),

	Author.Parallel({
		Rules = {
			-- forget structures
			Author.Rewrite("F > A"),
			Author.Rewrite("D > A"),
			Author.Rewrite("P > A"),
			Author.Rewrite("U > R"),
		},
	}),


----------------------------------------------------------------
	Author.Marker("Phase 8: Turn 1x1 Windows Into Walls"),
-- 	Turn the remaining 1x1 windows into walls
----------------------------------------------------------------
	
	Author.Parallel({
		Rules = {
			Author.Rewrite([[
				A A A A A > A A A A A
				---
				A R R R A > A A A A A
				---
				A R R R A > A A A A A
				---
				A R R R A > A A A A A
				---
				A R R R A > A A A A A
				---
				A A A A A > A A A A A
			]]),
		},
	}),
}),

}, "(xy)"),

}
end
