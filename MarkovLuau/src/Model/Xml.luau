--!strict
--!native
--!optimize 2
local Xml = {}

export type XElement = {
	Name: string,
	Attrs: { [string]: string },
	Children: { XElement },
	Line: number,
}

local ENTITIES: { [string]: string } = {
	lt = "<",
	gt = ">",
	amp = "&",
	apos = "'",
	quot = '"',
}

local NAME_PATTERN = "^[%a_:][%w_:%-%.]*"

local function decodeEntities(s: string): string

	return (
		s:gsub("&(#?%w+);", function(entity: string): string

			if entity:sub(1, 1) == "#" then
				local codepoint = if entity:sub(2, 2) == "x" or entity:sub(2, 2) == "X"
					then tonumber(entity:sub(3), 16)
					else tonumber(entity:sub(2))

				if codepoint then

					return utf8.char(codepoint)
				end

				return "&" .. entity .. ";"
			end

			local replacement = ENTITIES[entity]

			return replacement or ("&" .. entity .. ";")
		end)
	)
end

type Cursor = { S: string, Pos: number, Line: number }

local function peek(c: Cursor): string
	return string.sub(c.S, c.Pos, c.Pos)
end

local function advance(c: Cursor, n: number)
	for i = c.Pos, c.Pos + n - 1 do
		if string.byte(c.S, i) == 10 then
			c.Line += 1
		end
	end

	c.Pos += n
end

local function skipWhitespace(c: Cursor)
	while c.Pos <= #c.S do
		local ch = peek(c)

		if ch == " " or ch == "\t" or ch == "\r" or ch == "\n" then
			advance(c, 1)
		else
			break
		end
	end
end

-- Skips the XML declaration (`<?xml ... ?>`) and any number of comments
-- (`<!-- ... -->`), interleaved with whitespace before real content
local function skipProlog(c: Cursor)
	while true do
		skipWhitespace(c)

		if string.sub(c.S, c.Pos, c.Pos + 1) == "<?" then
			local closeAt = string.find(c.S, "?>", c.Pos, true)
			assert(closeAt, `Xml: unterminated "<?...?>" declaration at line {c.Line}`)
			advance(c, closeAt + 2 - c.Pos)

		elseif string.sub(c.S, c.Pos, c.Pos + 3) == "<!--" then
			local closeAt = string.find(c.S, "-->", c.Pos, true)
			assert(closeAt, `Xml: unterminated comment at line {c.Line}`)
			advance(c, closeAt + 3 - c.Pos)

		else
			break
		end
	end
end


local function readName(c: Cursor): string
	local rest = string.sub(c.S, c.Pos)
	local name = string.match(rest, NAME_PATTERN)
	assert(name, `Xml: expected a name at line {c.Line}`)
	advance(c, #name)

	return name
end

local function readAttrs(c: Cursor): { [string]: string }
	local attrs: { [string]: string } = {}
	while true do
		skipWhitespace(c)
		local ch = peek(c)

		if ch == "" or ch == "/" or ch == ">" then
			break
		end

		local name = readName(c)
		skipWhitespace(c)
		assert(peek(c) == "=", `Xml: expected "=" after attribute "{name}" at line {c.Line}`)
		advance(c, 1)
		skipWhitespace(c)
		local quote = peek(c)
		assert(quote == '"' or quote == "'", `Xml: expected a quoted value for attribute "{name}" at line {c.Line}`)
		advance(c, 1)
		local closeAt = string.find(c.S, quote, c.Pos, true)
		assert(closeAt, `Xml: unterminated attribute value for "{name}" at line {c.Line}`)
		local raw = string.sub(c.S, c.Pos, closeAt - 1)
		advance(c, closeAt + 1 - c.Pos)
		attrs[name] = decodeEntities(raw)

	end

	return attrs
end

local function isWhitespaceOnly(s: string): boolean

	return string.match(s, "^%s*$") ~= nil
end

local function readElement(c: Cursor): XElement
	local line = c.Line

	assert(peek(c) == "<", `Xml: expected "<" at line {c.Line}`)

	advance(c, 1)
	local name = readName(c)
	local attrs = readAttrs(c)
	skipWhitespace(c)

	if peek(c) == "/" then
		advance(c, 1)

		assert(peek(c) == ">", `Xml: expected "/>" for "{name}" at line {c.Line}`)
		advance(c, 1)

		return { Name = name, Attrs = attrs, Children = {}, Line = line }
	end

	assert(peek(c) == ">", `Xml: expected ">" for "{name}" at line {c.Line}`)
	advance(c, 1)

	local children: { XElement } = {}
	while true do
		local textStart = c.Pos
		while c.Pos <= #c.S and peek(c) ~= "<" do
			advance(c, 1)
		end

		local text = string.sub(c.S, textStart, c.Pos - 1)
		assert(isWhitespaceOnly(text), `Xml: unexpected text content inside "{name}" at line {c.Line}`)

		assert(c.Pos <= #c.S, `Xml: unterminated element "{name}" (opened at line {line})`)

		if string.sub(c.S, c.Pos, c.Pos + 3) == "<!--" then
			local closeAt = string.find(c.S, "-->", c.Pos, true)

			assert(closeAt, `Xml: unterminated comment at line {c.Line}`)
			advance(c, closeAt + 3 - c.Pos)

		elseif string.sub(c.S, c.Pos, c.Pos + 1) == "</" then
			advance(c, 2)

			local closeName = readName(c)
			assert(closeName == name, `Xml: mismatched closing tag "</{closeName}>" for "<{name}>" at line {c.Line}`)
			skipWhitespace(c)
			assert(peek(c) == ">", `Xml: expected ">" to close "</{closeName}" at line {c.Line}`)
			advance(c, 1)

			break
		else
			table.insert(children, readElement(c))
		end
	end

	return { Name = name, Attrs = attrs, Children = children, Line = line }
end

function Xml.Parse(source: string): XElement
	local c: Cursor = { S = source, Pos = 1, Line = 1 }
	skipProlog(c)
	local root = readElement(c)
	skipProlog(c)

	return root
end

return Xml
