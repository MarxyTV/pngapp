local nuklear = require 'nuklear'

local ui = {
    nk = nil
}

setmetatable(ui, ui)

function ui:init()
    if (ui.nk ~= nil) then
        error('NuklearUI alread initialized.')
        return
    end

    ui.nk = nuklear.newUI()
end

function ui:update(dt, drawFunc)
    ui.nk:frameBegin()

    drawFunc(ui.nk)

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
	return  ui.nk:mousemoved(x, y, dx, dy, istouch)
end

function ui:textinput(text)
    ui.nk:textinput(text)
end

function ui:wheelmoved(x, y)
	return ui.nk:wheelmoved(x, y)
end

-- utility
function ui:sliderElement(label, min, current, max, step, decimals, suffix)
    ui.nk:layoutRow('dynamic', 25, 2)
    ui.nk:label(label)
    ui.nk:label(round(current, decimals) .. (suffix or ''), 'right')
    ui.nk:layoutRow('dynamic', 25, 1)
    return ui.nk:slider(min, current, max, step)
end

return ui
