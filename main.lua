require 'filefix'
require 'gamepadfix'
---@diagnostic disable-next-line: different-requires
local Collection = require 'ext.lua-collections.collections'
local binser = require 'ext.binser'
local Signal = require 'ext.hump.signal'

local config = require 'config'
local server = require 'server'
require 'utility'

local UI = require 'ui'
local avatar = require 'avatar'

-- tracking
local wave_data = nil

-- stuff
local microphone = nil

-- ui stuff
local dragging = false
local settings_open = true
local debug_open = false
local easeIndex = 0
local easeIndexTable = nil
local easingFunctions = {
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

-- debug
local max_amplitude = 0

-- calculate mic amplitude
local function getAmplitude()
    if wave_data == nil or wave_data:count() <= 0 then
        return 0
    end

    local value = math.abs(wave_data:min() - wave_data:max())

    if debug_open and value > max_amplitude then
        max_amplitude = value
    end

    return value
end

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
    UI:init()
    avatar:init()

    -- start mic
    microphone = love.audio.getRecordingDevices()[config.data.mic_index]

    if microphone ~= nil then
        microphone:start() -- start listening to mic
    end

    -- inverse index
    easeIndexTable = {}
    for k, v in pairs(easingFunctions) do
        easeIndexTable[v] = k
    end

    easeIndex = easeIndexTable[config.data.shake_type]

    -- start websocket server
    server:start(20501)

    -- signal listeners
    Signal.register('sleepToggle', avatar.sleepToggle)
    Signal.register('changeSlot', cmd_changeSlots)
end

-- [[
--  UI Functions
-- ]]
function MenuBar(ui)
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
            if ui:button(settings_open and 'Hide Settings' or 'Show Settings') then
                settings_open = not settings_open

                if settings_open then
                    ui:windowShow('Settings')
                else
                    ui:windowHide('Settings')
                end
                ui:popupClose()
            end

            if ui:button(debug_open and 'Hide Debug Menu' or 'Show Debug Menu') then
                debug_open = not debug_open
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
                    if microphone then
                        microphone:stop()
                    end
                    config.data.mic_index = index
                    microphone = deviceList[index]
                    microphone:start()
                end
            end
        end
        ui:menuEnd()
    end

    ui:windowEnd()
end

local cr, cg, cb = 0, 0, 0

function SettingsWindow(ui)
    if ui:windowBegin('Settings', 0, 25, 360, love.graphics.getHeight() - 25, 'border', 'scrollbar') then
        config.data.talk_threshold = UI:sliderElement('Talk Threshold', 0, config.data.talk_threshold,
            config.data.scream_threshold, 0.001, 3)
        config.data.scream_threshold = UI:sliderElement('Scream Threshold', config.data.talk_threshold,
            config.data.scream_threshold, 2, 0.001, 3)
        config.data.decay_time = UI:sliderElement('Talk Decay', 0, config.data.decay_time, 1000, 10, 0, 'ms')


        config.data.blink_chance = UI:sliderElement('Blink Chance', 0, config.data.blink_chance, 100, 1, 0, '%')
        config.data.blink_duration = UI:sliderElement('Blink Duration', 10, config.data.blink_duration, 4000, 10, 0, 'ms')
        config.data.blink_delay = UI:sliderElement('Blink Delay', 10, config.data.blink_delay, 4000, 10, 3, 'ms')

        ui:layoutRow('dynamic', 20, 1)
        ui:label('Shake Type')
        ui:layoutRow('dynamic', 30, 1)
        easeIndex = easeIndexTable[config.data.shake_type] -- incase we reset or something
        easeIndex = ui:combobox(easeIndex, easingFunctions)
        config.data.shake_type = easingFunctions[easeIndex]

        config.data.shake_scale = UI:sliderElement('Shake Scale', 0, config.data.shake_scale, 200, 0.5)
        config.data.scream_shake_scale = UI:sliderElement('Scream Shake Scale', 0, config.data.scream_shake_scale, 200,
            0.5)
        config.data.shake_lerp_speed = UI:sliderElement('Shake Lerp Speed', 10, config.data.shake_lerp_speed, 2000, 10)
        config.data.shake_delay = UI:sliderElement('Shake Delay', 0, config.data.shake_delay, 1000, 1)


        ui:layoutRow('dynamic', 20, 1)
        ui:label('Background Color')
        ui:layoutRow('dynamic', 20, 1)
        config.data.bg_color.r = ui:property('Red', 0, config.data.bg_color.r, 255, 1, 1)
        config.data.bg_color.g = ui:property('Green', 0, config.data.bg_color.g, 255, 1, 1)
        config.data.bg_color.b = ui:property('Blue', 0, config.data.bg_color.b, 255, 1, 1)

    end

    ui:windowEnd()
end

function DebugWindow(ui)
    if ui:windowBegin('Debug', 360, 25, 200, 200,
        'border', 'title', 'movable', 'scalable') then

        ui:layoutRow('dynamic', 50, 1)
        ui:label(string.format('Amplitude: %.3f', getAmplitude()))
        ui:label(string.format('Max Amplitude: %.3f', max_amplitude))
    end
    ui:windowEnd()
end

local combo = { value = 1, items = { 'A', 'B', 'C' } }

function TestWindow(ui)
    if ui:windowBegin('Simple Example', 100, 100, 200, 160,
        'border', 'title', 'movable') then
        ui:layoutRow('dynamic', 30, 1)
        ui:label('Hello, world!')
        ui:layoutRow('dynamic', 30, 2)
        ui:label('Combo box:')
        if ui:combobox(combo, combo.items) then
            print('Combo!', combo.items[combo.value])
        end
        ui:layoutRow('dynamic', 30, 3)
        ui:label('Buttons:')
        if ui:button('Sample') then
            print('Sample!')
        end
        if ui:button('Button') then
            print('Button!')
        end
    end
    ui:windowEnd()
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

    -- update mic data
    if microphone ~= nil then
        local mic_buffer = microphone:getData()

        wave_data = collect({})

        if mic_buffer ~= nil then
            -- sample data starts at index 0
            for i = 0, mic_buffer:getSampleCount() - 1 do
                wave_data:push(mic_buffer:getSample(i))
            end
        end
    end

    -- update avatar
    avatar:update(dt, getAmplitude())

    -- update ui
    UI:update(dt, function(ui)
        MenuBar(ui)
        SettingsWindow(ui)

        if debug_open then
            DebugWindow(ui)
        end
    end)
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
    if microphone then
        microphone:stop()
    end
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
        config.data.offsetx = config.data.offsetx + dx
        config.data.offsety = config.data.offsety + dy

        avatar:update_offsets()
    end
end

function love.textinput(text)
    UI:textinput(text)
end

function love.wheelmoved(x, y)
    if not UI:wheelmoved(x, y) then
        if y ~= 0 then
            config.data.zoom = config.data.zoom + (y * 0.1)

            if config.data.zoom < 0.1 then
                config.data.zoom = 0.1
            end
        end
    end
end

function love.gamepadpressed(joystick, button)
    if button == 'b' then

    end
end
