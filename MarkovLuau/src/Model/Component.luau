--!strict
--!native
--!optimize 2
local Contract = require(script.Parent.Contract)
local Loader = require(script.Parent.Loader)

local Component = {}

export type RoleKind = "Symbol" | "Group" | "Any"
export type RoleDecl = { [string]: RoleKind }
export type Bindings = { [string]: any }

export type ComponentDef = {
	Reads: RoleDecl?,
	Writes: RoleDecl?,
	Private: { string }?,
	Ensures: { Contract.Check }?,
	Consumes: string?,
	Produces: string?,
	Body: (roles: { [string]: string }, args: Bindings) -> { Loader.Spec },
}

export type ComponentInstance = (bindings: Bindings) -> Loader.Spec

local function mergeRoles(
	name: string,
	def: ComponentDef
): RoleDecl
	local merged: RoleDecl = {}

	if def.Reads then
		for role, kind in def.Reads do
			merged[role] = kind
		end
	end

	if def.Writes then
		for role, kind in def.Writes do
			assert(kind == "Symbol", `Component "{name}": write role "{role}" must be a concrete Symbol, a Group can't be a rule output`)
			
			local existing = merged[role]
			assert(existing == nil or existing == "Symbol" or existing == "Any", `Component "{name}": role "{role}" is a Group in reads but a Symbol in writes -- pick one`)
			
			merged[role] = "Symbol"
		end
	end

	return merged
end

function Component.New(
	name: string,
	def: ComponentDef
): ComponentInstance
	local roles = mergeRoles(name, def)

	return function(bindings: Bindings): Loader.Spec
		local roleSpecs: { Loader.ScopeRoleSpec } = {}
		local roleNames: { [string]: string } = {}

		for role, kind in roles do
			local bind: Loader.ScopeRoleBinding

			if kind == "Any" then
				bind = "Any"
			else
				local symName = bindings[role]
				assert(symName, `Component "{name}": missing binding for role "{role}"`)
				
				bind = if kind == "Group" then { Group = symName } else symName
			end

			table.insert(roleSpecs, { Char = role, Bind = bind, Role = role })
			roleNames[role] = role
		end

		local children = def.Body(roleNames, bindings)
		local source, line = debug.info(2, "sl")

		return {
			Kind = "Scope",
			Roles = roleSpecs,
			Private = def.Private,
			Ensures = def.Ensures,
			Name = name,
			Children = children,
			Origin = `{source}:{line}`,
		} :: any
	end
end

return Component
