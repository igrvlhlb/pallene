local type_extractor = {}

local primitives_type_names = {
    ["types.T.Float"]       = "float",
    ["types.T.Integer"]     = "integer",
    ["types.T.String"]      = "string",
    ["types.T.Boolean"]     = "boolean",
    ["types.T.Nil"]         = "nil",
    ["types.T.Any"]         = "any",
}

local function format_type(type)
    if type._tag == "ast.Type.Nil" then
        return "nil"
    elseif type._tag == "ast.Type.Name" then
        return type.name
    elseif type._tag == "ast.Type.Array" then
        return "{" .. format_type(type.subtype) .. "}"
    elseif type._tag == "ast.Type.Table" then
        local fields = {}
        for _, field in ipairs(type.fields) do
            table.insert(fields, field.name .. ": " .. format_type(field.type))
        end
        return "{" .. table.concat(fields, ", ") .. "}"
    elseif type._tag == "ast.Type.Function" or type._tag == "types.T.Function" then
        local arg_types = type.arg_types
        local ret_types = type.ret_types
        local arg_strs  = {}
        local ret_strs  = {}
        for _, arg_type in ipairs(arg_types) do
            table.insert(arg_strs, format_type(arg_type))
        end
        for _, ret_type in ipairs(ret_types) do
            table.insert(ret_strs, format_type(ret_type))
        end
        local argstr = table.concat(arg_strs, ', ')
        local retlist = table.concat(ret_strs, ', ')
        local retstr = (#ret_strs > 1) and '(' .. retlist .. ')' or retlist
        return string.format("(%s) -> %s", argstr, retstr)
    elseif type._tag == "types.T.Table" then
        local fields = {}
        for name, field_type in pairs(type.fields) do
            table.insert(fields, string.format("%s: %s", name, format_type(field_type)))
        end
        return "{" .. table.concat(fields, ", ") .. "}"
    elseif type._tag == "types.T.Record" then
        return type.name
    elseif primitives_type_names[type._tag] then
        return primitives_type_names[type._tag]
    elseif type._tag == "types.T.Array" then
        return "{" .. format_type(type.elem) .. "}"
    else
        error("Unknown type: " .. tostring(type._tag))
    end
end

local function typeof_tls(node, typedefs)
    if node._tag == "ast.Toplevel.Typealias" then
        local type_name = node.name
        local type_def  = node.type
        table.insert(typedefs, string.format("typealias %s = %s", type_name, format_type(type_def)))
    elseif node._tag == "ast.Toplevel.Record" then
        local type_name = node.name
        local fields    = node.field_decls
        local field_strs = {}
        for _, field in ipairs(fields) do
            local typestr = format_type(field.type)
            table.insert(field_strs, string.format("%s: %s", field.name, typestr))
        end
        table.insert(typedefs, string.format("record %s: %s", type_name, table.concat(field_strs, "; ")))
    elseif node._tag == "ast.Toplevel.Stats" then
        local stats = node.stats
        for _, stat in ipairs(stats) do
            if stat._tag == "ast.Stat.Assign" then
                local vars = stat.vars
                for _, var in ipairs(vars) do
                    if var._tag == "ast.Var.Name" then
                        local name = var.name
                        local type = var._type
                        table.insert(typedefs, string.format("%s: %s", name, format_type(type)))
                    end
                end
            elseif stat._tag == "ast.Stat.Functions" then
                local funcs = stat.funcs
                for _, func in ipairs(funcs) do
                    if func.module then
                        table.insert(typedefs, string.format("%s: %s", func.name, format_type(func._type)))
                    end
                end
            elseif stat._tag == "ast.Stat.Decl" then
                -- do nothing
            else
                error("Unknown statement type: " .. tostring(stat._tag))
            end
        end
    else
        error("Unknown node type: " .. tostring(node._tag))
    end
end

function type_extractor.generate_type_declarations(prog_ast)
    local typedefs = {}
    for _, node in ipairs(prog_ast.tls) do
        typeof_tls(node, typedefs)
    end
    return typedefs
end

return type_extractor
