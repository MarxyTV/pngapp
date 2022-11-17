local nuklear = require 'nuklear'

local MenuBar = require 'menus.MenuBar'
local SettingsMenu = require 'menus.Settings'
local DebugMenu = require 'menus.Debug'
local ImageSelect = require 'menus.ImageSelect'

local ui = {
    nk = nil,
}

setmetatable(ui, ui)

function ui:init()
    if (ui.nk ~= nil) then
        error('NuklearUI alread initialized.')
        return
    end

    ui.nk = nuklear.newUI()

    MenuBar:init()
    SettingsMenu:init()
    DebugMenu:init()
    ImageSelect:init()
end

function ui:update(dt)
    ui.nk:frameBegin()

    MenuBar:update(ui.nk)

    if MenuBar.debug_open then
        DebugMenu:update(ui.nk)
    end

    SettingsMenu:update(ui.nk)

    if SettingsMenu.openImageSelect then
        ImageSelect:update(ui.nk)
    end

    ui.nk:frameEnd()
end

function ui:draw()
    ui.nk:draw()
end

function ui:shutdown()
end

function ui:keypressed(key, scancode, isrepeat)
    ui.nk:keypressed(key, scancode, isrepeat)
end

function ui:keyreleased(key, scancode)
    ui.nk:keyreleased(key, scancode)
end

function ui:mousepressed(x, y, button, istouch, presses)
    return ui.nk:mousepressed(x, y, button, istouch, presses)
end

function ui:mousereleased(x, y, button, istouch, presses)
    return ui.nk:mousereleased(x, y, button, istouch, presses)
end

function ui:mousemoved(x, y, dx, dy, istouch)
    return ui.nk:mousemoved(x, y, dx, dy, istouch)
end

function ui:textinput(text)
    ui.nk:textinput(text)
end

function ui:wheelmoved(x, y)
    return ui.nk:wheelmoved(x, y)
end

return ui
