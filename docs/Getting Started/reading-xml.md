---
sidebar_position: 6
---
# Reading XML Files

MarkovLuau supports the original MarkovJunior XML format. If you prefer XML, you can load XML strings directly.

## Loading an XML String

You use the `MarkovJunior.RunXml` function to run an XML string.

```lua
local xmlString = [[
<sequence>
    <rule in="B" out="R" />
</sequence>
]]

-- Run the XML on a 10x10x1 grid.
-- 1 is the random seed.
local grid = MarkovJunior.RunXml(xmlString, 10, 10, 1, 1)
```

## XML Features

The XML parser supports all original MarkovJunior features. You can define sequences, rules, and WFC nodes in the XML.

You can also use the `<markov>` node to run a set of rules repeatedly. The system stops when no rules in the markov node can find a match.

If you have a complex XML model from the original MarkovJunior project, it should work perfectly in MarkovLuau.
