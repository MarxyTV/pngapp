local config = require 'config'
local avatar = require 'avatar'
local audio = require 'audio'

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
        if ui:menuBegin('File', 'none', 150, 200) then
            ui:layoutRow('dynamic', 20, 1)
            if ui:button('Save') then
                config:save()
                ui:popupClose()
            end
            if ui:button('Undo Changes') then
                config:undo_changes()
                avatar:update_offsets()
                ui:popupClose()
            end
            if ui:button('Load Defaults') then
                config:reset()
                avatar:update_offsets()
                ui:popupClose()
            end
            if ui:button('Quit') then
                love.event.quit()
            end
        end
        ui:menuEnd()

        if ui:menuBegin('View', 'none', 150, 200) then
            ui:layoutRow('dynamic', 20, 1)
            if ui:button(MenuBar.settings_open and 'Hide Settings' or 'Show Settings') then
                MenuBar.settings_open = not MenuBar.settings_open

                if MenuBar.settings_open then
                    ui:windowShow('Settings')
                else
                    ui:windowHide('Settings')
                end
                ui:popupClose()
            end

            if ui:button(MenuBar.debug_open and 'Hide Debug Menu' or 'Show Debug Menu') then
                MenuBar.debug_open = not MenuBar.debug_open
                ui:popupClose()
            end
        end
        ui:menuEnd()

        if ui:menuBegin('Slot', 'none', 150, 250) then
            ui:layoutRow('dynamic', 20, 1)

            for i = 1, 10, 1 do
                if ui:button(string.format('Slot %d', i)) then
                    config:change_slot(i)
                    avatar:update_offsets()
                    ui:popupClose()
                end
            end
        end
        ui:menuEnd()

        if ui:menuBegin('Mic', 'none', 350, 250) then
            ui:layoutRow('dynamic', 20, 1)
            local deviceList = love.audio.getRecordingDevices()
            for index, inputDevice in ipairs(deviceList) do
                local labelText = (config.data.mic_index == index and 'X ' or ' ') ..
                    strsplit(inputDevice:getName(), " on ")[2]
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
