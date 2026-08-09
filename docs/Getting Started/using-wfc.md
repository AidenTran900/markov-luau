---
sidebar_position: 5
---
# Using Wave Function Collapse

Wave Function Collapse (WFC) lets you fill a space with complex patterns. MarkovLuau has two WFC nodes: Overlap and TileModel.

## The Overlap Node

The Overlap node reads a small sample grid. It learns the rules automatically from this sample. 

You provide the name of the sample. You also provide an `N` value. The `N` value sets the size of the patterns that the algorithm looks for. An `N` value of 3 means the algorithm looks at 3x3x3 blocks. A larger `N` value makes larger, more accurate patterns. A smaller `N` value is faster but more random.

```lua
local wfcRule = MarkovJunior.Overlap({
    Name = "MySampleName",
    N = 3,
    Symmetry = "(X)"
}, "BR", {})
```

The `Symmetry` value tells the algorithm if it can rotate or flip the patterns. The string "(X)" means the pattern has reflectional symmetry on the X axis.

## The TileModel Node

The TileModel node gives you exact control. You define every tile and every connection manually. You use an XML string or a data table to define the tiles.

```lua
local tileRule = MarkovJunior.TileModel({
    Name = "MyTileset",
    Symmetry = "(I)"
}, "BR", {})
```

## Adding WFC to a Sequence

You add a WFC node to your sequence exactly like a Markov rule.

```lua
local mySequence = MarkovJunior.Sequence({
    wfcRule
})
```

WFC algorithms can fail. If the algorithm cannot find a valid tile for a cell, it stops. When you run the sequence, you must check if the generation completed successfully. You can use the `MarkovJunior.Retry` node to automatically retry a WFC node if it fails.
