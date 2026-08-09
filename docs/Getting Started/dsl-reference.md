---
sidebar_position: 7
---
# DSL Reference

This page lists all nodes available in the MarkovLuau Domain Specific Language (DSL). You can build complex generation logic with these nodes.

## Branch Nodes

Branch nodes contain other nodes. They control the execution flow.

### Sequence

The `Sequence` node runs its child nodes in order. It starts with the first child. When the first child finishes, it moves to the second child.

```lua
local mySequence = MarkovJunior.Sequence({
    childNode1,
    childNode2
})
```

### Markov

The `Markov` node runs its child nodes repeatedly. It starts from the first child. If a child makes a change, the `Markov` node stops and restarts from the first child again. It only finishes when no child can make a change.

```lua
local myMarkov = MarkovJunior.Markov({
    childNode1,
    childNode2
})
```

## Rule Nodes

Rule nodes apply pattern matching logic to the grid.

### One

The `One` node searches for a pattern. It applies the change only one time per step. It picks a random match if there are multiple matches.

```lua
local rule = MarkovJunior.One({
    Rules = {
        MarkovJunior.Rule("B", "R")
    }
})
```

### All

The `All` node searches for a pattern. It applies the change to every match it finds at the exact same time.

```lua
local rule = MarkovJunior.All({
    Rules = {
        MarkovJunior.Rule("B", "R")
    }
})
```

### Parallel

The `Parallel` node acts like the `All` node. It applies changes to all matches. However, it applies the changes in independent steps. This prevents overlapping matches from causing conflicts.

```lua
local rule = MarkovJunior.Parallel({
    Rules = {
        MarkovJunior.Rule("B", "R")
    }
})
```

## Helper Rules

You use these functions to define the input and output for Rule nodes.

### Rule

The `Rule` function creates a simple rule. You provide an input string and an output string.

```lua
local myRule = MarkovJunior.Rule("B", "R")
```

### Rewrite

The `Rewrite` function creates a complex rule with a visual pattern. You use lines to draw the shape.

```lua
local myRewrite = MarkovJunior.Rewrite([[
    B B B
    B B B
    B B B
    ->
    R R R
    R R R
    R R R
]])
```

## WFC Nodes

These nodes use Wave Function Collapse.

### Overlap

The `Overlap` node learns rules from a sample grid automatically.

```lua
local overlapNode = MarkovJunior.Overlap({
    Name = "MySampleName",
    N = 3,
    Symmetry = "(X)"
}, "BR", {})
```

### TileModel

The `TileModel` node lets you specify exact tiles and connections manually.

```lua
local tileNode = MarkovJunior.TileModel({
    Name = "MyTileset",
    Symmetry = "(I)"
}, "BR", {})
```

## Advanced Nodes

These nodes perform complex or utility tasks.

### Path

The `Path` node finds a path between two points. It draws the path on the grid.

```lua
local pathNode = MarkovJunior.Path({
    From = "A",
    To = "B",
    On = "*",
    Color = "P"
})
```

### Convolution

The `Convolution` node runs cellular automata logic. It changes cells based on neighbor counts. You use this for smooth generation.

```lua
local convNode = MarkovJunior.Convolution({
    Steps = 10,
    Rules = { ... }
})
```

### ConvChain

The `ConvChain` node combines MCMC logic and pattern learning. It forces the grid to look like a small sample.

```lua
local chainNode = MarkovJunior.ConvChain({
    Name = "SampleGrid",
    Steps = 100
})
```

### Map

The `Map` node acts as a macro. It replaces a color with a small pattern of colors.

```lua
local mapNode = MarkovJunior.Map({
    Rule = MarkovJunior.MapRule(nil, nil, { In = "A", Out = "B" })
}, "AB", {})
```

### Retry

The `Retry` node runs a child node. If the child fails, the `Retry` node tries again up to a limit. You often use this with WFC nodes or structural constraints.

```lua
local retryNode = MarkovJunior.Retry({
    Body = mySequence,
    Attempts = 5
})
```

### Budget

The `Budget` node runs a child node but limits its time. If the child takes too long, it stops.

```lua
local budgetNode = MarkovJunior.Budget({
    Body = mySequence,
    Steps = 1000
})
```

### Seed

The `Seed` node places a pre-made block of voxels into the grid instantly.

```lua
local seedNode = MarkovJunior.Seed("MyVoxelModel")
```

### Marker

The `Marker` node does nothing to the grid. It leaves a named tag in the `InterpreterState`. You use this to track progress in your code.

```lua
local markerNode = MarkovJunior.Marker("GenerationPhase2")
```

### Scope

The `Scope` node creates an isolated execution context. Nodes inside a `Scope` node operate on a separate grid or with different symbols.

```lua
local scopeNode = MarkovJunior.Scope(
    localGrid, 
    { mySequence }
)
```
