local serialize = require 'lib.ser'

local config = {
    extension = 'lua',
    data = nil
}

local default_config = {
    -- bound settings
    talk_threshold = 0.045,
    scream_threshold = 0.47,
    decay_time = 0.25,
    shake_scale = 15.0,
    scream_shake_scale = 25.0,
    shake_lerp_speed = 5.0,
    blink_chance = 0.25,
    blink_duration = 0.035,
    blink_delay = 0.25,
    -- stuff
    offsetx = 0,
    offsety = 0,
    zoom = 1,
    mic_index = 1,
    bg_color = "#00ff00"
}

setmetatable(config, config)

-- FileNameWithExtension
local function fnwe(fn)
    return string.format('%s.%s', fn, config.extension)
end

-- copy
local function copy(obj, seen)
    if type(obj) ~= 'table' then return obj end
    if seen and seen[obj] then return seen[obj] end
    local s = seen or {}
    local res = setmetatable({}, getmetatable(obj))
    s[obj] = res
    for k, v in pairs(obj) do res[copy(k, s)] = copy(v, s) end
    return res
end

-- load
function config:load(filename)
    local file = fnwe(filename)
    local fileInfo = love.filesystem.getInfo(file)

    if fileInfo == nil then
        print(string.format('File %s not found, loading default config', file))
        self:reset()
        return
    end

    self.data = love.filesystem.load(file)()
    print(string.format('Loaded file %s', file))
end

-- reset
function config:reset()
    self.data = copy(default_config)
    self.data.offsetx = (love.graphics.getWidth() / 2)
    self.data.offsety = (love.graphics.getHeight() / 2)
    print(string.format('Reset config data'))
end

-- save
function config:save(filename)
    local data = serialize(self.data)
    local file = fnwe(filename)
    local success, msg = love.filesystem.write(file, data)

    if not success then
        print(string.format('Failed to save file %s: %s', file, msg))
    else
        print(string.format('Saved file as %s', file))
    end
end

return config