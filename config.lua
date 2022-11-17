local binser = require 'ext.binser'

require 'utility'

local config = {
    slot = 1,
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
    },
    images = {
        open_closed = nil,
        open_open = nil,
        closed_closed = nil,
        closed_open = nil,
        scream = nil,
        sleep = nil
    }
}

setmetatable(config, config)

-- FileNameWithExtension
local function fileForSlot(slot)
    return string.format('preset%d.bin', slot)
end

local function currentFile()
    return fileForSlot(config.slot)
end

-- load
function config:load()
    local file = currentFile()
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
function config:save()
    local data = binser.serialize(self.data)
    local file = currentFile()
    local success, msg = love.filesystem.write(file, data)

    if not success then
        print(string.format('Failed to save file %s: %s', file, msg))
    else
        self.initial = copy_table(self.data) -- store new "initial"
        print(string.format('Saved file as %s', file))
    end
end

function config:change_slot(index, saveFirst)
    if saveFirst then
        self:save()
    end

    self.slot = index
    self:load()
end

function config:get_image(key)
    if self.data.images == nil then
        self.data.images = {}
    elseif self.data.images[key] ~= nil then
        return love.graphics.newImage(self.data.images[key])
    end

    return nil
end

function config:set_image(key, path)
    self.data.images[key] = path
end

return config
