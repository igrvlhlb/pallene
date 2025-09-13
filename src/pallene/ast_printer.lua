
local ast_printer = {}

local ast_common_fields = {
    _tag = true,
    _type = true,
    _def = true,
    loc = true,
}

local function is_identifier(str)
    local re = require "re"
    local pattern = re.compile "[_A-Za-z][_A-Za-z0-9]*"
    return pattern:match(str) == string.len(str) + 1
end


local function gettableaccessor(str)
    local isid = false
    local namestr
    if is_identifier(str) then
        namestr = str
        isid = true
    elseif type(str) == 'number' then
        namestr = '[' .. str .. ']'
    else
        namestr = '["' .. str .. '"]'
    end
    return namestr, isid
end

local function istbl(tbl) return type(tbl) == 'table' end

local function extract_defs(ast, deflist, defset)
    local deflist = deflist or {}
    local defset = defset or {}
    if not istbl(ast) then return end
    if defset[ast] then return end
    if ast._def then
        table.insert(deflist, ast._def)
        defset[ast._def] = #deflist
    end
    for k,v in pairs(ast) do
        if istbl(v) then
            extract_defs(v, deflist, defset)
        end
    end
    return deflist, defset
end

local function dfs_print_ast(this, level, label, defset)
	local result = ""
	local indent = string.rep(" ", level + 1)

    if (this._tag) then
        result = result .. indent .. "_tag = " .. this._tag .. "\n"
    end
    if (this.loc) then
        result = result .. indent .. "loc = " .. tostring(this.loc:show_line()) .. "\n"
    end
    if (this._type) then
        local types = require "pallene.types"
        result = result .. indent .. "_type = " .. types.tostring(this._type) .. "\n"
    end
    if (this._def and defset) then
        if not defset[this._def] then
            error("missing def in defset")
        end
        result = result .. indent .. "_def = def " .. defset[this._def] .. "\n"
    end

	for name, value in pairs(this) do
        local namestr
        if type(name) == 'number' then namestr = tostring(name)
        else namestr = gettableaccessor(name) end

        if ast_common_fields[name] then
            -- skip common ast fields
		elseif not istbl(value) then
            local vstring = (type(value) == 'string') and string.format("%q", value) or tostring(value)
			result = result .. indent .. namestr .. " = " .. vstring .. "\n"
		elseif istbl(value) then
			result = result .. indent .. namestr .. " = {\n" .. dfs_print_ast(value, level+1, name, defset) .. indent .. "}\n"
		end
	end

	return result
end

local function def_tostring(def)
    if def._tag == "typechecker.Def.Variable" then
        return "var {\n" .. dfs_print_ast(def.decl, 0) .. "}"
    elseif def._tag == "typechecker.Def.Function" then
        return "func {\n" .. dfs_print_ast(def.func, 0) .. "}"
    elseif def._tag == "typechecker.Def.Builtin" then
        return "builtin " .. def.id
    else
        error("unknown def type " .. tostring(def._tag))
    end
end

function ast_printer.pretty_print(t, label)
	if not t then return nil end
    assert(t, 'no table provided')

	local label = label or "root"

	local result = ""

    local deflist, defset = extract_defs(t, deflist, defset)

    if #deflist > 0 then 
        print ("\n--== Definitions ==--\n")
        for i, def in ipairs(deflist) do
            print("def " .. i .. ": " .. def_tostring(def) )
        end
        print ("\n--== End of Definitions ==--\n")
    end

	result = label .. " = {\n"

    result = result .. dfs_print_ast(t, 0, label, defset)

	result = result .. "}\n"

	return result
end

return ast_printer