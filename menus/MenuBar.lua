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
    ui:window('MenuBar', 0, 0, love.graphics.getWidth(), 25, function()
        ui:menubar(function()
            ui:layoutRow('static', 20, 30, 5)
            ui:menu(lang('ui/file'), 'none', 150, 200, function()
                ui:layoutRow('dynamic', 20, 1)
                if ui:menuItem(lang('ui/save')) then
                    config:save()
                end
                if ui:menuItem(lang('ui/undo')) then
                    config:undo_changes()
                    avatar:update_offsets()
                end
                if ui:menuItem(lang('ui/defaults')) then
                    config:reset()
                    avatar:update_offsets()
                end
                if ui:menuItem(lang('ui/quit')) then
                    love.event.quit()
                end
            end)

            ui:menu(lang('ui/view'), 'none', 150, 200, function()
                ui:layoutRow('dynamic', 20, 1)
                if ui:menuItem(MenuBar.settings_open and lang('ui/hidesettings') or lang('ui/showsettings')) then
                    MenuBar.settings_open = not MenuBar.settings_open

                    if MenuBar.settings_open then
                        ui:windowShow('Settings')
                    else
                        ui:windowHide('Settings')
                    end
                end

                if ui:menuItem(MenuBar.debug_open and lang('ui/hidedebug') or lang('ui/showdebug')) then
                    MenuBar.debug_open = not MenuBar.debug_open
                end
            end)

            ui:menu(lang('ui/slot'), 'none', 150, 250, function()
                ui:layoutRow('dynamic', 20, 1)

                for i = 1, 10, 1 do
                    if ui:menuItem(string.format(lang('ui/slot') .. ' %d', i)) then
                        config:change_slot(i)
                        avatar:update_offsets()
                    end
                end
            end)

            ui:menu(lang('ui/mic'), 'none', 350, 250, function()
                ui:layoutRow('dynamic', 20, 1)
                local deviceList = love.audio.getRecordingDevices()
                for index, inputDevice in ipairs(deviceList) do
                    local deviceName = inputDevice:getName()

                    if string.find(deviceName, ' on ') then
                        deviceName = strsplit(deviceName, ' on ')[2]
                    end

                    local labelText = (config.data.mic_index == index and 'X ' or ' ') .. deviceName
                    if ui:menuItem(labelText) then
                        config.data.mic_index = index
                        audio:setMicrophone(inputDevice)
                    end
                end
            end)

            ui:menu(lang('ui/language'), 'none', 150, 200, function ()
                ui:layoutRow('dynamic', 20, 1)
                for _, locale in ipairs(lang:get_locales()) do
                    if ui:menuItem(locale) then
                        lang:set_locale(locale)
                    end
                end
            end)
        end)
    end)
end

return MenuBar
