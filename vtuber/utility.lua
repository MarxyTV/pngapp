-- round
function round(value, decimals)
    local mult = math.pow(10, decimals or 0) -- round to 0 places when d not supplied
    return math.floor(value * mult + 0.5) / mult
end

-- copy
function copy_table(obj, seen)
    if type(obj) ~= 'table' then return obj end
    if seen and seen[obj] then return seen[obj] end
    local s = seen or {}
    local res = setmetatable({}, getmetatable(obj))
    s[obj] = res
    for k, v in pairs(obj) do res[copy_table(k, s)] = copy_table(v, s) end
    return res
end