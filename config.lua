local binser = require 'ext.binser'

require 'utility'

local config = {
    extension = 'data',
    data = nil,
    initial = nil
}

local default_config = {
    -- bound settings
    talk_threshold = 0.045,
    scream_threshold = 0.47,
    decay_time = 250,
    shake_scale = 15.0,
    scream_shake_scale = 25.0,
    shake_lerp_speed = 500,
    shake_delay = 50,
    shake_type = 'linear',
    blink_chance = 25,
    blink_duration = 35,
    blink_delay = 250,
    -- stuff
    offsetx = 0,
    offsety = 0,
    zoom = 1,
    mic_index = 1,
    bg_color = {
        r = 0,
        g = 255,
        b = 0
    }
}

setmetatable(config, config)

-- FileNameWithExtension
local function fnwe(fn)
    return string.format('%s.%s', fn, config.extension)
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

    local buffer, size = love.filesystem.read(file)
    local data, len = binser.deserialize(buffer)
    self.data = copy_table(data[1])
    self.initial = copy_table(data[1]) -- store this so we can undo changes later
    print(string.format('Loaded file %s', file))
end

-- undo changes
function config:undo_changes()
    self.data = copy_table(self.initial)
    print('Undid changes')
end

-- reset
function config:reset()
    self.data = copy_table(default_config)
    self.data.offsetx = (love.graphics.getWidth() / 2)
    self.data.offsety = (love.graphics.getHeight() / 2)
    print(string.format('Reset config data'))
end

-- save
function config:save(filename)
    local data = binser.serialize(self.data)
    local file = fnwe(filename)
    local success, msg = love.filesystem.write(file, data)

    if not success then
        print(string.format('Failed to save file %s: %s', file, msg))
    else
        self.initial = copy_table(self.data) -- store new "initial"
        print(string.format('Saved file as %s', file))
    end
end

return config