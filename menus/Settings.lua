local config = require 'config'
local lang = require 'lang'
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
    }
}

setmetatable(SettingsMenu, SettingsMenu)

function SettingsMenu:init()
    -- inverse index
    SettingsMenu.easeIndexTable = {}
    for k, v in pairs(SettingsMenu.easingFunctions) do
        SettingsMenu.easeIndexTable[v] = k
    end
    SettingsMenu.easeIndex = SettingsMenu.easeIndexTable[config.data.shake_type]
end

function SettingsMenu:update(ui)
    if ui:windowBegin('Settings', 0, 25, 360, love.graphics.getHeight() - 25, 'border', 'scrollbar') then
        config.data.talk_threshold = sliderElement(ui, lang('ui/talkthreshold'), 0, config.data.talk_threshold,
            config.data.scream_threshold, 0.001, 3)
        config.data.scream_threshold = sliderElement(ui, lang('ui/screamthreshold'), config.data.talk_threshold,
            config.data.scream_threshold, 2, 0.001, 3)
        config.data.decay_time = sliderElement(ui, lang('ui/talkdecay'), 0, config.data.decay_time, 1000, 10, 0, 'ms')


        config.data.blink_chance = sliderElement(ui, lang('ui/blinkchance'), 0, config.data.blink_chance, 100, 1, 0, '%')
        config.data.blink_duration = sliderElement(ui, lang('ui/blinkduration'), 10, config.data.blink_duration, 4000, 10, 0, 'ms')
        config.data.blink_delay = sliderElement(ui, lang('ui/blinkdelay'), 10, config.data.blink_delay, 4000, 10, 3, 'ms')

        ui:layoutRow('dynamic', 20, 1)
        ui:label(lang('ui/shaketype'))
        ui:layoutRow('dynamic', 30, 1)
        SettingsMenu.easeIndex = SettingsMenu.easeIndexTable[config.data.shake_type] -- incase we reset or something
        SettingsMenu.easeIndex = ui:combobox(SettingsMenu.easeIndex, SettingsMenu.easingFunctions)
        config.data.shake_type = SettingsMenu.easingFunctions[SettingsMenu.easeIndex]

        config.data.shake_scale = sliderElement(ui, lang('ui/shakescale'), 0, config.data.shake_scale, 200, 0.5)
        config.data.scream_shake_scale = sliderElement(ui, lang('ui/shakescreamscale'), 0, config.data.scream_shake_scale, 200,
            0.5)
        config.data.shake_lerp_speed = sliderElement(ui, lang('ui/shakelerpspeed'), 10, config.data.shake_lerp_speed, 2000, 10)
        config.data.shake_delay = sliderElement(ui, lang('ui/shakedelay'), 0, config.data.shake_delay, 1000, 1)


        ui:layoutRow('dynamic', 20, 1)
        ui:label(lang('ui/bgcolor'))
        ui:layoutRow('dynamic', 20, 1)
        config.data.bg_color.r = ui:property(lang('ui/red'), 0, config.data.bg_color.r, 255, 1, 1)
        config.data.bg_color.g = ui:property(lang('ui/green'), 0, config.data.bg_color.g, 255, 1, 1)
        config.data.bg_color.b = ui:property(lang('ui/blue'), 0, config.data.bg_color.b, 255, 1, 1)

    end

    ui:windowEnd()
end

return SettingsMenu
