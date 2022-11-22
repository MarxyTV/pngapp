local Signal = require 'ext.hump.signal'

require 'filefix'
require 'gamepadfix'
require 'utility'

local avatar = require 'avatar'
local audio = require 'audio'
local config = require 'config'
local server = require 'server'
local UI = require 'ui'
local lang = require 'lang'

local dragging = false

-- command to change selected slot
local function cmd_changeSlots(args)
    local slot = args['slot']

    if slot == nil or slot < 0 or slot > 10 then
        print('cmd_changeSlots: Invalid slot number')
        return
    end

    config:change_slot(slot)
    avatar:update_offsets()
end

-- entry point
function love.load(args)
    config:load()
    lang:init()
    avatar:init()
    audio:init()
    UI:init()

    -- start websocket server
    server:start(20501)

    -- signal listeners
    Signal.register('sleepToggle', avatar.sleepToggle)
    Signal.register('changeSlot', cmd_changeSlots)
end

function love.update(dt)
    server:update()

    -- check preset selection hotkey
    if love.keyboard.isDown('lctrl') and love.keyboard.isDown('lshift') then
        for i = 9, 0, -1 do
            local slot = i

            if slot == 0 then slot = 10 end

            if love.keyboard.isDown(i) and config.slot ~= slot then
                config:change_slot(slot)
            end
        end
    end

    audio:update(dt)
    avatar:update(dt)
    UI:update(dt)
end

function love.draw()
    love.graphics.setBackgroundColor(config.data.bg_color.r / 255,
        config.data.bg_color.g / 255,
        config.data.bg_color.b / 255, 0)
    avatar:draw()
    UI:draw()
end

function love.quit()
    server:stop()
    UI:shutdown()
    avatar:shutdown()
    audio:shutdown()
end

-- input forwarding

function love.keypressed(key, scancode, isrepeat)
    UI:keypressed(key, scancode, isrepeat)
end

function love.keyreleased(key, scancode)
    UI:keyreleased(key, scancode)
end

function love.mousepressed(x, y, button, istouch, presses)
    if not UI:mousepressed(x, y, button, istouch, presses) then
        -- start draging if not ui press and right click
        if button == 2 and not avatar.isSleeping then
            dragging = true
        end
    end
end

function love.mousereleased(x, y, button, istouch, presses)
    if not UI:mousereleased(x, y, button, istouch, presses) then
    end

    -- stop dragging on right click release
    -- we want this even if ui captures it so it doesnt get stuck dragging
    if button == 2 then
        dragging = false
    end
end

function love.mousemoved(x, y, dx, dy, istouch)
    if not UI:mousemoved(x, y, dx, dy, istouch) then
    end

    -- if not clicked on menu, drag menu
    if dragging then
        config.data.offsetx = config.data.offsetx - dx
        config.data.offsety = config.data.offsety - dy

        avatar:update_offsets()
    end
end

function love.textinput(text)
    UI:textinput(text)
end

function love.wheelmoved(x, y)
    if not UI:windowIsAnyHovered() or not UI:wheelmoved(x, y) then
        if y ~= 0 then
            config.data.zoom = config.data.zoom + (y * 0.1)

            if config.data.zoom < 0.1 then
                config.data.zoom = 0.1
            end
        end
    end
end

function love.gamepadpressed(joystick, button)
end

function love.filedropped(file)
    local supported = {
        "jpg",
        "jpeg",
        "png",
        "bmp",
        "tga",
        "hdr",
        "pic",
        "exr"
    }
    local ext = file:getExtension()

    for _, value in ipairs(supported) do
        print(value)
        if ext == value then
            file:open("r")
            local data = file:read()
            file:close()
            local fileName = GetBaseFilename(file:getFilename())
            local newFile = love.filesystem.newFile('images/' .. fileName)
            newFile:open('w')
            newFile:write(data)
            newFile:flush()
            newFile:close()
            return
        end
    end

    print('Unsupported file type ' .. ext)
end
