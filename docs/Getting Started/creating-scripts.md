---
sidebar_position: 4
---
# Creating Your First Script

You use the `MarkovJunior` module to write your scripts. This section shows you how to write a simple script.

## 1. Require the Module

First, require the module in your script.

```lua
local MarkovJunior = require(path.to.MarkovJunior)
```

## 2. Define a Rule

You define rules to tell the algorithm what to do. The `MarkovJunior.One` function creates a node that applies a rule only one time per step. 

Create a simple node. This node looks for a blue cell (B). It changes that blue cell to a red cell (R).

```lua
local changeColorNode = MarkovJunior.One({
    Rules = {
        MarkovJunior.Rule("B", "R")
    }
})
```

You can also use `MarkovJunior.All`. The `All` node applies the change to every match it finds at the same time.

## 3. Build the Sequence

You must tell the model the correct order to run the nodes. You use a sequence for this. A sequence is a list of nodes. The algorithm runs the nodes in order.

```lua
local mySequence = MarkovJunior.Sequence({
    changeColorNode
})
```

You can add many nodes to a sequence. You can also add other sequences inside a sequence. This lets you build complex logic.

## 4. Run the Code

Now, apply the sequence to your model and run it on a grid. You use the `MarkovJunior.RunSpec` function. 

You must provide six things:
1. The sequence.
2. The alphabet. This is a string of characters that represents all possible states for a cell. For example, `"BR"` means the grid can have blue (B) and red (R) cells.
3. The grid width (X axis).
4. The grid height (Y axis).
5. The grid depth (Z axis).
6. A random seed number.

```lua
local width = 10
local height = 10
local depth = 1
local seed = 12345

local grid = MarkovJunior.RunSpec(
    mySequence, 
    "BR", 
    width, 
    height, 
    depth, 
    seed
)
```

The function returns the final grid. You can then read the cells from this grid to create parts in your game. You can use `MarkovJunior.Export` and `MarkovJunior.MeshPass` to turn the grid data into 3D meshes easily.
