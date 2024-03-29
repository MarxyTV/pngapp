local nuklear = require 'nuklear'
local binser = require 'ext.binser'

require 'utility'

local config = {
    slot = 1,
    data = nil,
    initial = nil
}

local default_config = {
    -- bound settings
    talk_enabled = true,
    talk_threshold = 0.045,
    scream_enabled = true,
    scream_threshold = 0.47,
    decay_time = 250,
    shake_enabled = true,
    shake_scale = 15.0,
    scream_shake_scale = 25.0,
    shake_lerp_speed = 500,
    shake_delay = 50,
    shake_type = 'linear',
    blink_enabled = true,
    blink_chance = 25,
    blink_duration = 35,
    blink_delay = 250,
    sleep_lerp_speed = 1000,
    sleep_distance = 20,
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
    },
    ui_states = {}
}

setmetatable(config, config)

-- FileNameWithExtension
local function fileForSlot(slot)
    return string.format('preset%d.bin', slot)
end

local function currentFile()
    return fileForSlot(config.slot)
end

function config:fixValue(key, default)
    if config.data[key] == nil then
        config.data[key] = default
    end
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

    --#region Update old config
    for key, value in pairs(default_config) do
        if self.data[key] == nil then
            self.data[key] = value
        end
    end
    --#endregion Update old config

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

function config:get_uistate(key)
    return (self.data.ui_states[key] ~= nil and self.data.ui_states[key])
        and 'expanded' or 'collapsed'
end

function config:set_uistate(key, open)
    self.data.ui_states[key] = open
end

function config:set_image(key, path)
    self.data.images[key] = path
end

function config:set_color(r, g, b)
    self.data.bg_color.r = r
    self.data.bg_color.g = g
    self.data.bg_color.b = b
end

function config:get_colorhex()
    return nuklear.colorRGBA(self.data.bg_color.r,
        self.data.bg_color.g,
        self.data.bg_color.b)
end

function config:set_colorhex(string)
    self:set_color(nuklear.colorParseRGBA(string))
end

return config
