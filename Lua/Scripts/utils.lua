-- Created by TontonSamael --

---@param obj any
---@param key? any
---@param level? integer
function Dump(obj, key, level)
    level = level or 0
    local keyPrefix = ""
    if key ~= nil then
        keyPrefix = string.format("%s (%s) = ", tostring(key), type(key))
    end
    local indent = ""
    for _ = 1, level do
        indent = indent .. "  "
    end

    if type(obj) == "table" then
        print(string.format("%s%s{ (table)", indent, keyPrefix))
        if level < 20 then
            for k, v in pairs(obj) do
                Dump(v, k, level + 1)
            end
        else
            print(string.format("%sMax level reached", indent))
        end
        print(string.format("%s}", indent))
    else
        print(string.format("%s%s%s (%s)", indent, keyPrefix, tostring(obj), type(obj)))
    end
end

-- FILE UTILS

_G.file = {}

---@param path string
function file.exists(path)
    if type(path) ~= "string" then return false end
    if #path == 0 then return false end
    if string.sub(path, -1) ~= "/" then
        -- add last slash if missing
        path = path .. "\\"
    end
    local status, err, code = os.rename(path, path)
    if not status and code == 13 then
        -- permission denied but folder exists
        return true
    end
    return status
end

---@param path string
function file.isDir(path)
    if type(path) ~= "string" then return false end
    if #path == 0 then return false end
    if not file.exists(path) then return false end
    local file = io.open(path, "r")
    if file then
        return false
    end
    return true
end

-- STRING UTILS

---@param str string
---@param sep string
string.split = string.split or function(str, sep)
    if type(str) ~= "string" then return {} end
    if type(sep) ~= "string" then return {} end
    local t = {}
    for s in string.gmatch(str, "([^" .. sep .. "]+)") do
        table.insert(t, s)
    end
    return t
end

---@param str string
---@return string
string.capitalize = string.capitalize or function(str)
    if type(str) ~= "string" then return str end
    local res = str:lower():gsub("^%l", string.upper)
    return res
end

-- TABLE/ARRAY UTILS

---@param tab any[]
---@param sep? string
table.join = table.join or function(tab, sep)
    if type(tab) ~= "table" then return "" end
    if type(sep) ~= "string" then sep = "" end
    local str = "";
    for i, v in ipairs(tab) do
        str = str .. tostring(v)
        if i ~= #tab then
            str = str .. sep
        end
    end
    return str
end

---@param target table<any, any>
---@param source table<any, any>
---@param level? integer
table.assign = table.assign or function(target, source, level)
    if type(target) ~= "table" or type(source) ~= "table" then return target end
    if not level then
        level = 1
    elseif level >= 20 then
        return {}
    end
    for k, v in pairs(source) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then
                target[k] = {}
            end
            table.assign(target[k], v, level + 1)
        else
            target[k] = v
        end
    end
end

---@generic K, V
---@param tab table<K, V>
---@return table<K, V>
---@param level? integer
table.clone = table.clone or function(tab, level)
    if type(tab) ~= "table" then return {} end
    if not level then
        level = 1
    elseif level >= 20 then
        return {}
    end
    local res = {}
    for k, v in pairs(tab) do
        if type(v) == "table" then
            res[k] = table.clone(v, level + 1)
        elseif type(v) ~= "function" then
            res[k] = v
        end
    end
    return res
end

---@generic K, V, T
---@param tab table<K, V>
---@param mapFn fun(el: V, index: K, tab: table<K, V>): T
---@return table<K, T>
table.map = table.map or function(tab, mapFn)
    if type(tab) ~= "table" then return {} end
    if type(mapFn) ~= "function" then return {} end
    local status
    local res = {}
    for k, v in pairs(tab) do
        status, res[k] = pcall(mapFn, v, k, tab)
        if not status then
            res[k] = nil
        end
    end
    return res
end

---@generic K, V
---@param tab table<K, V>
---@param filterFn fun(el: V, index: K, tab: table<K, V>): boolean
---@return table<K, V>
table.filter = table.filter or function(tab, filterFn)
    if type(tab) ~= "table" then return {} end
    if type(filterFn) ~= "function" then return {} end
    local res = {}
    for k, v in pairs(tab) do
        local status, cond = pcall(filterFn, v, k, tab)
        if status and cond then
            res[k] = v
        end
    end
    return res
end

---@generic K, V
---@param tab table<K, V>
---@param someFn fun(el: V, index: K, tab: table<K, V>): boolean
---@return boolean
table.some = table.some or function(tab, someFn)
    if type(tab) ~= "table" then return false end
    if type(someFn) ~= "function" then return false end
    for k, v in pairs(tab) do
        local status, cond = pcall(someFn, v, k, tab)
        if status and cond then
            return true
        end
    end
    return false
end
table.any = table.some

---@generic K, V
---@param tab table<K, V>
---@param everyFn fun(el: V, index: K, tab: table<K, V>): boolean
---@return boolean
table.every = table.every or function(tab, everyFn)
    if type(tab) ~= "table" then return false end
    if type(everyFn) ~= "function" then return false end
    for k, v in pairs(tab) do
        local status, cond = pcall(everyFn, v, k, tab)
        if not status or not cond then
            return false
        end
    end
    return true
end
table.all = table.every

---@generic K, V, T
---@param tab table<K, V>
---@param reduceFn fun(value: T, el: V, index: K, tab: table<K, V>): T
---@param initialValue T
---@return T
table.reduce = table.reduce or function(tab, reduceFn, initialValue)
    if initialValue == nil then return initialValue end
    if type(tab) ~= "table" then return initialValue end
    if type(reduceFn) ~= "function" then return initialValue end
    local res = initialValue
    for k, v in pairs(tab) do
        local status, value = pcall(reduceFn, res, v, k, tab)
        if status then
            res = value
        end
    end
    return res
end

---@generic K, V
---@param tab table<K, V>
---@param foreachFn fun(el: V, index: K, tab: table<K, V>)
table.forEach = table.forEach or function(tab, foreachFn)
    if type(tab) ~= "table" then return end
    if type(foreachFn) ~= "function" then return end
    for k, v in pairs(tab) do
        foreachFn(v, k, tab)
    end
end

---@generic K, V
---@param tab table<K, V>
---@param findFn fun(el: V, index: K, tab: table<K, V>): boolean
---@return V, K | nil
table.find = table.find or function(tab, findFn)
    if type(tab) ~= "table" then return nil end
    if type(findFn) ~= "function" then return nil end
    for k, v in pairs(tab) do
        local status, cond = pcall(findFn, v, k, tab)
        if status and cond then
            return v, k
        end
    end
    return nil
end

---@param tab table<any, any>
---@return integer
table.length = table.length or function(tab)
    if type(tab) ~= "table" then return 0 end
    local sum = 0
    table.forEach(tab, function() sum = sum + 1 end)
    return sum
end

---@generic K
---@param tab table<K, any>
---@return K[]
table.keys = table.keys or function(tab)
    if type(tab) ~= "table" then return {} end
    local res = {}
    for k in pairs(tab) do
        table.insert(res, k)
    end
    table.sort(res)
    return res
end

---@generic V
---@param tab table<any, V>
---@return V[]
table.values = table.values or function(tab)
    if type(tab) ~= "table" then return {} end
    local res = {}
    for _, v in pairs(tab) do
        table.insert(res, v)
    end
    table.sort(res)
    return res
end

table.includes = table.includes or function(tab, el)
    if type(tab) ~= "table" then return false end
    for _, v in pairs(tab) do
        if v == el then
            return true
        end
    end
    return false
end
table.contains = table.includes

---@param tab1 any[]
---@param tab2 any[]
---@return boolean
table.compare = table.compare or function(tab1, tab2)
    if type(tab1) ~= "table" or type(tab2) ~= "table" then return tab1 == tab2 end
    if #tab1 ~= #tab2 then return false end
    for i = 1, #tab1 do
        if tab1[i] ~= tab2[i] then
            return false
        end
    end
    return true
end

-- MATH UTILS

---@param value number
---@param fromMin number
---@param fromMax number
---@param toMin number
---@param toMax number
---@return number
math.map = math.map or function(value, fromMin, fromMax, toMin, toMax)
    if not table.every({ value, fromMin, fromMax, toMin, toMax }, function(V) return type(V) == "number" end) then
        return value
    end
    return (value - fromMin) / (fromMax - fromMin) * (toMax - toMin) + toMin
end
math.scale = math.map

---@param value number
---@param min? number
---@param max? number
---@return number
math.clamp = math.clamp or function(value, min, max)
    if not table.every({ value, min, max }, function(V) return type(V) == "number" end) then
        return value
    end
    if min ~= nil and value < min then
        value = min
    elseif max ~= nil and value > max then
        value = max
    end
    return value
end

math.round = math.round or function(value, precision)
    precision = precision or 0
    if precision < 0 then
        return value
    end
    return tonumber(string.format("%." .. tostring(precision) .. "f", value))
end
