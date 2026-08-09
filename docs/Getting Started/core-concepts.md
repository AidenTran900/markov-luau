---
sidebar_position: 2
---
# Core Concepts

MarkovLuau uses two primary logic systems for generation. It is important to understand how the system stores data before you learn the algorithms.

## The Grid and Cells

MarkovLuau stores all data in a 3D grid. The grid has a width, height, and depth. You can think of the grid as a box of small cubes. We call each cube a cell. 

Each cell holds one value. In MarkovLuau, we represent these values as characters. For example, a cell can hold the letter `R` for red, or the letter `B` for blue. You define an alphabet of characters when you start the generation.

## Markov Algorithms

A Markov algorithm searches for a specific pattern in the grid. You give the algorithm a rule. The rule has two parts: an input pattern and an output pattern.

When the algorithm finds the input pattern in the grid, it replaces the pattern with the output pattern. 

### How Rules Work

1. The algorithm scans the entire grid.
2. It looks for cells that match the input pattern exactly.
3. If it finds a match, it changes those cells to the output pattern.
4. The algorithm repeats this process. It stops only when it cannot find any more matches.

This system is very powerful. You can write simple rules that grow complex shapes. For example, you can write a rule that changes one red cell into two red cells. The algorithm will run this rule over and over. The red cells will spread across the entire grid.

## Wave Function Collapse (WFC)

Wave Function Collapse acts like a puzzle. You provide small pieces, called tiles. You also give rules that tell the system how these tiles connect to each other.

### The Constraint System

WFC uses constraints. A constraint is a rule that limits what can happen. For example, a constraint can say: "A road tile must connect to another road tile."

The WFC algorithm follows these steps:
1. It looks at the empty grid. Every cell can be any tile.
2. It picks one cell and chooses a tile for that cell. This is the collapse.
3. It updates the neighbor cells. Because the first cell is now a road tile, the neighbor cells can only be tiles that connect to a road.
4. It repeats this process until the grid is full.

WFC ensures that all connections obey your rules. You use WFC to build complex structures that look natural.

## Grid Locking

You can lock cells in the grid. A locked cell has a protected value. Rules can read the value of a locked cell. However, rules cannot change the value of a locked cell. You use grid locking to protect important structures from accidental changes.

## Field Potentials

MarkovLuau uses field potentials to guide the generation. A field potential is a map of distances. The algorithm uses this map to find the shortest path or the nearest object. You use field potentials to generate rivers, roads, and connecting paths.

## Interpreter and Time Travel

The Interpreter runs your generation model step by step. It saves the state of the grid after every step. We call this time travel. You can pause, rewind, and replay the generation. This feature is very useful for debugging your rules.

## Meshing and Output

MarkovLuau provides modules to help you convert the final grid into a 3D model. You use the `MeshPass` and `Export` modules. These tools read the grid values and build the correct geometry.
