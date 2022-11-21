local config = require 'config'
local lang = require 'lang'
local avatar = require 'avatar'
local pretty = require 'pl.pretty'
require 'ui_util'

local SettingsMenu = {
    easeIndex = 0,
    easeIndexTable = nil,
    easingFunctions = {
        'linear',
        -- quad
        'inQuad',
        'outQuad',
        'inOutQuad',
        'outInQuad',
        -- cubic
        'inCubic',
        'outCubic',
        'inOutCubic',
        'outInCubic'
    },
    frames = collect({
        'open_closed',
        'open_open',
        'closed_closed',
        'closed_open',
        'scream',
        'sleep'
    }),
    openImageSelect = false,
    imageKey = nil
}

setmetatable(SettingsMenu, SettingsMenu)

function SettingsMenu:init()
    -- inverse index
    self.easeIndexTable = {}
    for k, v in pairs(self.easingFunctions) do
        self.easeIndexTable[v] = k
    end
    self.easeIndex = self.easeIndexTable[config.data.shake_type]
end

function SettingsMenu:drawImage(ui, frame)
    local img = avatar.frames[frame]
    if ui:button(img == nil and nil or "none", img) then
        if frame ~= self.imageKey then
            self.openImageSelect = true
            self.imageKey = frame
        else -- close window if we click on the same one
            self.openImageSelect = false
            self.imageKey = nil
        end
    end
end

function SettingsMenu:update(ui)
    if ui:windowBegin('Settings', 0, 25, 360, love.graphics.getHeight() - 25, 'border', 'scrollbar') then
        local cols = 2

        if ui:treePush('tab', lang('ui/talkingframes'), nil, 'collapsed') then
            ui:layoutRow('dynamic', 150, cols)
            self:drawImage(ui, 'open_closed')
            self:drawImage(ui, 'open_open')

            ui:layoutRow('dynamic', 20, cols)
            ui:label('Mouth Closed')
            ui:label('Mouth Opened')
            ui:treePop()
        end

        if ui:treePush('tab', lang('ui/blinkingframes'), nil, 'collapsed') then
            ui:layoutRow('dynamic', 150, cols)
            self:drawImage(ui, 'closed_closed')
            self:drawImage(ui, 'closed_open')

            ui:layoutRow('dynamic', 20, cols)
            ui:label('Mouth Closed')
            ui:label('Mouth Opened')
            ui:treePop()
        end

        if ui:treePush('tab', lang('ui/extraframes'), nil, 'collapsed') then
            ui:layoutRow('dynamic', 150, cols)
            self:drawImage(ui, 'scream')
            self:drawImage(ui, 'sleeping')

            ui:layoutRow('dynamic', 20, cols)
            ui:label('Scream/Mic Peak')
            ui:label('Sleeping')
            ui:treePop()
        end

        if ui:treePush('tab', lang('ui/talksettings'), nil, 'expanded') then
            config.data.talk_threshold = sliderElement(ui, lang('ui/talkthreshold'), 0, config.data.talk_threshold,
                config.data.scream_threshold, 0.001, 3)
            config.data.scream_threshold = sliderElement(ui, lang('ui/screamthreshold'), config.data.talk_threshold,
                config.data.scream_threshold, 2, 0.001, 3)
            config.data.decay_time = sliderElement(ui, lang('ui/talkdecay'), 0, config.data.decay_time, 1000, 10, 0, 'ms')
            config.data.talk_enabled = ui:checkbox('Talk Enabled', config.data.talk_enabled)
            config.data.scream_enabled = ui:checkbox('Scream Enabled', config.data.scream_enabled)
            ui:treePop()
        end

        if ui:treePush('tab', lang('ui/blinksettings'), nil, 'expanded') then
            config.data.blink_chance = sliderElement(ui, lang('ui/blinkchance'), 0, config.data.blink_chance, 100, 1, 0,
                '%')
            config.data.blink_duration = sliderElement(ui, lang('ui/blinkduration'), 10, config.data.blink_duration, 4000
                , 10, 0, 'ms')
            config.data.blink_delay = sliderElement(ui, lang('ui/blinkdelay'), 10, config.data.blink_delay, 4000, 10, 3,
                'ms')
            config.data.blink_enabled = ui:checkbox('Blink Enabled', config.data.blink_enabled)
            ui:treePop()
        end

        if ui:treePush('tab', lang('ui/shakesettings'), nil, 'expanded') then
            ui:layoutRow('dynamic', 20, 1)
            ui:label(lang('ui/shaketype'))
            ui:layoutRow('dynamic', 30, 1)
            self.easeIndex = self.easeIndexTable[config.data.shake_type] -- incase we reset or something
            self.easeIndex = ui:combobox(self.easeIndex, self.easingFunctions)
            config.data.shake_type = self.easingFunctions[self.easeIndex]
            config.data.shake_scale = sliderElement(ui, lang('ui/shakescale'), 0, config.data.shake_scale, 200, 0.5)
            config.data.scream_shake_scale = sliderElement(ui, lang('ui/shakescreamscale'), 0,
                config.data.scream_shake_scale, 200, 0.5)
            config.data.shake_lerp_speed = sliderElement(ui, lang('ui/shakelerpspeed'), 10, config.data.shake_lerp_speed
                , 2000, 10)
            config.data.shake_delay = sliderElement(ui, lang('ui/shakedelay'), 0, config.data.shake_delay, 1000, 1)
            config.data.shake_enabled = ui:checkbox('Shake Enabled', config.data.shake_enabled)
            ui:treePop()
        end

        if ui:treePush('tab', lang('ui/bgsettings'), nil, 'expanded') then
            ui:layoutRow('dynamic', 20, 1)
            ui:label(lang('ui/bgcolor'))
            config.data.bg_color.r = ui:property(lang('ui/red'), 0, config.data.bg_color.r, 255, 1, 1)
            config.data.bg_color.g = ui:property(lang('ui/green'), 0, config.data.bg_color.g, 255, 1, 1)
            config.data.bg_color.b = ui:property(lang('ui/blue'), 0, config.data.bg_color.b, 255, 1, 1)
            ui:treePop()
        end
    end

    ui:windowEnd()
end

return SettingsMenu
