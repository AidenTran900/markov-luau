--!strict
--!native
--!optimize 2
--[=[
	@class Pattern
	
	Parses multi-line string pattern literals into tokens for rewrite rules.
]=]
local Pattern = {}

export type Grid3D = { string } -- 1-indexed, x fastest then y then z (Rule.Parse's own shape)

export type ParseResult = {
	InTokens: Grid3D,
	IMX: number,
	IMY: number,
	IMZ: number,
	OutTokens: Grid3D,
	OMX: number,
	OMY: number,
	OMZ: number,
}

local function idx1(
	mx: number,
	my: number,
	x: number,
	y: number,
	z: number
): number

	return z * mx * my + y * mx + x + 1
end

local function isBlank(line: string): boolean

	return string.match(line, "^%s*$") ~= nil
end

local function isLayerBreak(line: string): boolean

	return string.match(line, "^[%s%-]*%-[%s%-]*$") ~= nil
end

local function errorAt(
	rawLines: { string },
	lineNum: number,
	col: number,
	msg: string
)
	local src = rawLines[lineNum] or ""
	local caret = string.rep(" ", math.max(col - 1, 0)) .. "^"
	error(`Pattern.Parse: {msg} (line {lineNum}, column {col})\n{src}\n{caret}`, 0)
end

local function tokenize(text: string): { string }
	local out = {}

	for tok in string.gmatch(text, "%S+") do
		table.insert(out, tok)
	end

	return out
end

type LayerLine = { LineNum: number, Text: string }

--[=[
	Parses a literal multiline string into a structural rule pattern.
	@param raw string -- The raw string literal containing the pattern definition.
	@return table -- A structured ParseResult containing 3D grid token arrays.
]=]
function Pattern.Parse(raw: string): ParseResult
	local rawLines: { string } = {}

	for line in (raw .. "\n"):gmatch("(.-)\n") do
		table.insert(rawLines, line)
	end

	-- Group non-blank lines into per-z-layer blocks, split on "---" lines.
	local layers: { { LayerLine } } = { {} }

	for i, line in rawLines do

		if isLayerBreak(line) then
			table.insert(layers, {})
		elseif not isBlank(line) then
			table.insert(layers[#layers], { LineNum = i, Text = line })
		end
	end

	while #layers > 0 and #layers[#layers] == 0 do
		table.remove(layers)
	end

	assert(#layers > 0, "Pattern.Parse: literal has no content")

	local inLayers: { { { string } } } = {}
	local outLayers: { { { string } } } = {}
	local imx: number? = nil
	local imy: number? = nil
	local omx: number? = nil
	local omy: number? = nil

	for li, layerLines in layers do
		assert(#layerLines > 0, `Pattern.Parse: layer {li} is empty`)

		-- The split column comes from whichever line(s) in this layer carry
		-- ">"; every line that has one must agree on where.
		local col: number? = nil

		for _, entry in layerLines do
			local at = string.find(entry.Text, ">", 1, true)

			if at then

				if col == nil then
					col = at
				elseif col ~= at then
					errorAt(rawLines, entry.LineNum, at, `">" must line up with the same column as the rest of this layer`)
				end
			end
		end

		if col == nil then
			errorAt(rawLines, layerLines[1].LineNum, 1, `layer {li} has no ">" separating input from output`)
		end

		local splitCol = col :: number

		local inRows: { { string } } = {}
		local outRows: { { string } } = {}

		for _, entry in layerLines do
			local leftText = string.sub(entry.Text, 1, splitCol - 1)
			local rightText = string.sub(entry.Text, splitCol + 1)
			local inRow = tokenize(leftText)
			local outRow = tokenize(rightText)

			if #inRow == 0 then
				errorAt(rawLines, entry.LineNum, 1, "empty input row")
			end

			if #outRow == 0 then
				errorAt(rawLines, entry.LineNum, splitCol + 1, "empty output row")
			end

			table.insert(inRows, inRow)
			table.insert(outRows, outRow)
		end

		local thisImx = #inRows[1]
		local thisOmx = #outRows[1]

		for ri, row in inRows do

			if #row ~= thisImx then
				errorAt(rawLines, layerLines[ri].LineNum, 1, `row has {#row} input cells, expected {thisImx}`)
			end
		end

		for ri, row in outRows do

			if #row ~= thisOmx then
				errorAt(rawLines, layerLines[ri].LineNum, splitCol + 1, `row has {#row} output cells, expected {thisOmx}`)
			end
		end

		if imx == nil then
			imx, imy = thisImx, #inRows
			omx, omy = thisOmx, #outRows
		else
			assert(thisImx == imx and #inRows == imy, `Pattern.Parse: layer {li}'s input size doesn't match layer 1`)
			assert(thisOmx == omx and #outRows == omy, `Pattern.Parse: layer {li}'s output size doesn't match layer 1`)
		end

		table.insert(inLayers, inRows)
		table.insert(outLayers, outRows)
	end

	local imz, omz = #inLayers, #outLayers
	local fimx, fimy = imx :: number, imy :: number
	local fomx, fomy = omx :: number, omy :: number
	local inTokens: Grid3D = table.create(fimx * fimy * imz)
	local outTokens: Grid3D = table.create(fomx * fomy * omz)

	-- First-listed layer lands on top (z = mz - 1) -- mirrors Rule.Parse's
	-- `lines[mz - z]` reversal for the XML in="AAA BBB" mini-language.
	for z = 0, imz - 1 do
		local rows = inLayers[imz - z]
		for y = 0, fimy - 1 do
			local row = rows[y + 1]
			for x = 0, fimx - 1 do
				inTokens[idx1(fimx, fimy, x, y, z)] = row[x + 1]
			end
		end
	end

	for z = 0, omz - 1 do
		local rows = outLayers[omz - z]
		for y = 0, fomy - 1 do
			local row = rows[y + 1]
			for x = 0, fomx - 1 do
				outTokens[idx1(fomx, fomy, x, y, z)] = row[x + 1]
			end
		end
	end

	return {
		InTokens = inTokens,
		IMX = fimx,
		IMY = fimy,
		IMZ = imz,
		OutTokens = outTokens,
		OMX = fomx,
		OMY = fomy,
		OMZ = omz,
	}
end

return Pattern
