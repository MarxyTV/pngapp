local config = require 'config'
local avatar = require 'avatar'
local audio = require 'audio'
local lang = require 'lang'
local pretty = require 'pl.pretty'

local MenuBar = {
    settings_open = true,
    debug_open = false,
}

setmetatable(MenuBar, MenuBar)

function MenuBar:init()
end

function MenuBar:update(ui)
    if ui:windowBegin('MenuBar', 0, 0, love.graphics.getWidth(), 25, 'background') then
        ui:layoutRow('static', 20, 30, 4)
        if ui:menuBegin(lang('ui/file'), 'none', 150, 200) then
            ui:layoutRow('dynamic', 20, 1)
            if ui:button(lang('ui/save')) then
                config:save()
                ui:popupClose()
            end
            if ui:button(lang('ui/undo')) then
                config:undo_changes()
                avatar:update_offsets()
                ui:popupClose()
            end
            if ui:button(lang('ui/defaults')) then
                config:reset()
                avatar:update_offsets()
                ui:popupClose()
            end
            if ui:button(lang('ui/quit')) then
                love.event.quit()
            end
        end
        ui:menuEnd()

        if ui:menuBegin(lang('ui/view'), 'none', 150, 200) then
            ui:layoutRow('dynamic', 20, 1)
            if ui:button(MenuBar.settings_open and lang('ui/hidesettings') or lang('ui/showsettings')) then
                MenuBar.settings_open = not MenuBar.settings_open

                if MenuBar.settings_open then
                    ui:windowShow('Settings')
                else
                    ui:windowHide('Settings')
                end
                ui:popupClose()
            end

            if ui:button(MenuBar.debug_open and lang('ui/hidedebug') or lang('ui/showdebug')) then
                MenuBar.debug_open = not MenuBar.debug_open
                ui:popupClose()
            end
        end
        ui:menuEnd()

        if ui:menuBegin(lang('ui/slot'), 'none', 150, 250) then
            ui:layoutRow('dynamic', 20, 1)

            for i = 1, 10, 1 do
                if ui:button(string.format(lang('ui/slot') .. ' %d', i)) then
                    config:change_slot(i)
                    avatar:update_offsets()
                    ui:popupClose()
                end
            end
        end
        ui:menuEnd()

        if ui:menuBegin(lang('ui/mic'), 'none', 350, 250) then
            ui:layoutRow('dynamic', 20, 1)
            local deviceList = love.audio.getRecordingDevices()
            for index, inputDevice in ipairs(deviceList) do
                local deviceName = inputDevice:getName()

                if string.find(deviceName, ' on ') then
                    deviceName = strsplit(deviceName, ' on ')[2]
                end
                
                local labelText = (config.data.mic_index == index and 'X ' or ' ') .. deviceName
                if ui:button(labelText) then
                    config.data.mic_index = index
                    audio:setMicrophone(inputDevice)
                end
            end
        end
        ui:menuEnd()
    end

    ui:windowEnd()
end

return MenuBar
