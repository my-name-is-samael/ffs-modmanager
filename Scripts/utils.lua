local Utils = {}

---@param path string
function Utils.fileExists(path)
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

function Utils.isDir(path)
    if not Utils.fileExists(path) then return false end
    local file = io.open(path, "r")
    if file then
        return false
    end
    return true
end

string.split = string.split or function(str, sep)
    local t = {}
    for s in string.gmatch(str, "([^" .. sep .. "]+)") do
        table.insert(t, s)
    end
    return t
end

table.join = table.join or function(tab, sep)
    if type(tab) ~= "table" then return "" end
    local str = "";
    for i, v in ipairs(tab) do
        str = str .. tostring(v)
        if i ~= #tab then
            str = str .. sep
        end
    end
    return str
end

return Utils
