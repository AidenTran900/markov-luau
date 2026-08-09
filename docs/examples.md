---
sidebar_position: 2
---
# Examples

These examples show how to build complete procedural generation scripts. You can run these scripts directly in your project.

**Note:** All of these examples, including the original `Growth` XML and `Apartemazements` models, are included in the `src/Shared/MarkovData/` folder. You can run them directly in the actual Roblox game!

## Simple Growth

This script seeds a few black dots on the grid. The dots grow outwards and turn neighboring white cells into black cells.

```lua
local MarkovJunior = require(path.to.MarkovJunior)

-- Seed a few starting points randomly since we do not have Origin=true
local seedNode = MarkovJunior.Parallel({
    Rules = { MarkovJunior.Rewrite("W > B", { P = 0.005 }) },
    Steps = 1
})

-- We create a rule that finds a white cell (W) next to a black cell (B).
-- It changes the white cell to a black cell (B).
local growRule = MarkovJunior.Rule("WB", "BB")

-- We use 'One' so only one cell changes at a time.
local growNode = MarkovJunior.One({
    Rules = { growRule }
})

-- We need a sequence to run the node.
local sequence = MarkovJunior.Sequence({
    seedNode,
    growNode
})

-- Grid size
local width = 20
local height = 20
local depth = 1
local seed = 12345

-- Alphabet "WB" means White and Black.
local finalGrid = MarkovJunior.RunSpec(sequence, "WB", width, height, depth, seed)
```

## Finding a Path

This script uses the `Path` node. The algorithm draws the shortest line between a starting color and an ending color.

```lua
local MarkovJunior = require(path.to.MarkovJunior)

-- Seed starting (A) and ending (R) points randomly
local seedA = MarkovJunior.Parallel({
    Rules = { MarkovJunior.Rewrite("B > A", { P = 0.001 }) },
    Steps = 1
})
local seedR = MarkovJunior.Parallel({
    Rules = { MarkovJunior.Rewrite("B > R", { P = 0.001 }) },
    Steps = 1
})

-- We use the Path node.
-- It searches for color 'A' and draws a line to color 'B'.
-- It uses color 'P' for the path line.
local pathNode = MarkovJunior.Path({
    From = "A",
    To = "R",
    On = "B",
    Color = "P"
})

local sequence = MarkovJunior.Sequence({
    seedA,
    seedR,
    pathNode
})

-- Alphabet "BWARP" represents background, walls, start, end, and path
local finalGrid = MarkovJunior.RunSpec(sequence, "BWARP", 20, 20, 1, 123)
```

## Basic Wave Function Collapse

This script uses the `TileModel` node to build a grid using the pre-defined "Paths" sample from the `Resources` folder.

```lua
local MarkovJunior = require(path.to.MarkovJunior)

-- We use the TileModel node.
-- It reads the "Paths" tileset and maps W constraints to Empty.
local wfcNode = MarkovJunior.TileModel(tileModelConfig, "BYDAWPRFUENC", {})

local sequence = MarkovJunior.Sequence({
    -- Fill space with WFC 'N' constraints
    MarkovJunior.Parallel({ Rules = { MarkovJunior.Rewrite("B > N") } }),
    wfcNode
})

-- Run the WFC algorithm.
local finalGrid = MarkovJunior.RunSpec(sequence, "BWN", 8, 8, 8, 123)
```

## Original Models

You can also find the original models ported from MarkovJunior inside `src/Shared/MarkovData/`:
* **Growth**: A simple XML model that grows outwards using the `Origin = true` flag.
* **Apartemazements**: A complex architectural model ported from MarkovJunior [(original here)](https://github.com/mxgmn/MarkovJunior/blob/main/models/Apartemazements.xml).
