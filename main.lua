require 'filefix'
require 'gamepadfix'
local nuklear = require 'nuklear'
local Collection = require 'ext.lua-collections.collections'
local binser = require 'ext.binser'
local tween = require 'ext.tween'
local Signal = require 'ext.hump.signal'

local config = require 'config'
local server = require 'server'
require 'utility'

local ui = nil

-- tracking
local talk_type = 0
local talk_end_time = 0
local blink_time = 0
local blink_end_time = 0
local shake_end_time = 0
local do_blink = false
local wave_data = nil
local current_frame = nil
local image_pos = {
    x = 0,
    y = 0
}
local image_tween = nil
local isSleeping = false

-- stuff
local microphone = nil
local frames = {
    open_closed = nil,
    open_open = nil,
    closed_closed = nil,
    closed_open = nil,
    scream = nil,
    sleep = nil
}

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

local sleepStart = { x = 0, y = 0 }
local sleepEnd = { x = 0, y = 0 }
local sleepDirection = 0

-- debug
local max_amplitude = 0

function default_position()
    return {
        x = config.data.offsetx or 0,
        y = config.data.offsety or 0
    }
end

function update_offsets()
    image_tween = nil
    image_pos.x = config.data.offsetx
    image_pos.y = config.data.offsety
end

function love.load(args)
    config:load()

	ui = nuklear.newUI()

    -- load image frames
    frames.open_closed = love.graphics.newImage("assets/eyes_open_mouth_closed.png")
    frames.open_open = love.graphics.newImage("assets/eyes_open_mouth_open.png")
    frames.closed_closed = love.graphics.newImage("assets/eyes_closed_mouth_closed.png")
    frames.closed_open = love.graphics.newImage("assets/eyes_closed_mouth_open.png")
    frames.scream = love.graphics.newImage("assets/scream.png")
    frames.sleep = love.graphics.newImage("assets/sleep.png")

    microphone = love.audio.getRecordingDevices()[config.data.mic_index]

    if microphone ~= nil then
        microphone:start() -- start listening to mic
    end

    image_pos = default_position()

    -- inverse index
    easeIndexTable = {}
    for k, v in pairs(easingFunctions) do
        easeIndexTable[v] = k
    end

    easeIndex = easeIndexTable[config.data.shake_type]

    server:start(20501)

    -- signal listeners
    Signal.register('sleepToggle', cmd_sleepToggle)
    Signal.register('changeSlot', cmd_changeSlots)
end

-- [[
--  Commands
-- ]]
function cmd_sleepToggle()
    isSleeping = not isSleeping

    if isSleeping then
        local tmpPos = default_position()
        tmpPos.y = tmpPos.y - 20
        image_pos = default_position()
        image_pos.y = image_pos.y + 20
        sleepDirection = 0
        startSleepTween(image_pos, tmpPos)
        sleepStart = copy_table(tmpPos)
        sleepEnd = copy_table(image_pos)
    else
        image_tween = nil
        update_offsets()
    end
end

function cmd_changeSlots(args)
    local slot = args['slot']

    if slot == nil or slot < 0 or slot > 10 then
        print('cmd_changeSlots: Invalid slot number')
        return
    end

    config:change_slot(slot)
    update_offsets()
end

-- [[
--  UI Functions
-- ]]
function MenuBar()
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
                update_offsets()
                ui:popupClose()
            end
            if ui:button('Load Defaults') then
                config:reset()
                update_offsets()
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
                    update_offsets()
                    ui:popupClose()
                end
            end
        end
        ui:menuEnd()

        if ui:menuBegin('Mic', 'none', 350, 250) then
            ui:layoutRow('dynamic', 20, 1)
            local deviceList = love.audio.getRecordingDevices()
            for index, inputDevice in ipairs(deviceList) do
                local labelText = (config.data.mic_index == index and 'X ' or ' ') .. strsplit(inputDevice:getName(), " on ")[2]
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

function sliderElement(label, min, current, max, step, decimals, suffix)
    ui:layoutRow('dynamic', 25, 2)
    ui:label(label)
    ui:label(round(current, decimals) .. (suffix or ''), 'right')
    ui:layoutRow('dynamic', 25, 1)
    return ui:slider(min, current, max, step)
end

local cr, cg, cb = 0, 0, 0

function SettingsWindow()
    if ui:windowBegin('Settings', 0, 25, 360, love.graphics.getHeight() - 25, 'border', 'scrollbar') then
        config.data.talk_threshold = sliderElement('Talk Threshold', 0, config.data.talk_threshold, config.data.scream_threshold, 0.001, 3)
        config.data.scream_threshold = sliderElement('Scream Threshold', config.data.talk_threshold, config.data.scream_threshold, 2, 0.001, 3)
        config.data.decay_time = sliderElement('Talk Decay', 0, config.data.decay_time, 1000, 10, 0, 'ms')


        config.data.blink_chance = sliderElement('Blink Chance', 0, config.data.blink_chance, 100, 1, 0, '%')
        config.data.blink_duration = sliderElement('Blink Duration', 10, config.data.blink_duration, 4000, 10, 0, 'ms')
        config.data.blink_delay = sliderElement('Blink Delay', 10, config.data.blink_delay, 4000, 10, 3, 'ms')

        ui:layoutRow('dynamic', 20, 1)
        ui:label('Shake Type')
        ui:layoutRow('dynamic', 30, 1)
        easeIndex = easeIndexTable[config.data.shake_type] -- incase we reset or something
        easeIndex = ui:combobox(easeIndex, easingFunctions)
        config.data.shake_type = easingFunctions[easeIndex]

        config.data.shake_scale = sliderElement('Shake Scale', 0, config.data.shake_scale, 200, 0.5)
        config.data.scream_shake_scale = sliderElement('Scream Shake Scale', 0, config.data.scream_shake_scale, 200, 0.5)
        config.data.shake_lerp_speed = sliderElement('Shake Lerp Speed', 10, config.data.shake_lerp_speed, 2000, 10)
        config.data.shake_delay = sliderElement('Shake Delay', 0, config.data.shake_delay, 1000, 1)


        ui:layoutRow('dynamic', 20, 1)
        ui:label('Background Color')
        ui:layoutRow('dynamic', 20, 1)
        config.data.bg_color.r = ui:property('Red', 0, config.data.bg_color.r, 255, 1, 1)
        config.data.bg_color.g = ui:property('Green', 0, config.data.bg_color.g, 255, 1, 1)
        config.data.bg_color.b = ui:property('Blue', 0, config.data.bg_color.b, 255, 1, 1)

    end

    ui:windowEnd()
end

function DebugWindow()
    if ui:windowBegin('Debug', 360, 25, 200, 200,
            'border', 'title', 'movable', 'scalable') then

        ui:layoutRow('dynamic', 50, 1)
        ui:label(string.format('Amplitude: %.3f', getAmplitude()))
        ui:label(string.format('Max Amplitude: %.3f', max_amplitude))
    end
    ui:windowEnd()
end

function getAmplitude()
    if wave_data == nil or wave_data:count() <= 0 then
        return 0
    end

    local value = math.abs(wave_data:min() - wave_data:max())

    if debug_open and value > max_amplitude then
        max_amplitude = value
    end

    return value
end

function updateShake(magnitude)
    local t = love.timer.getTime() * 1000

    if t - shake_end_time > config.data.shake_delay then
        shake_end_time = t + config.data.shake_delay
        image_pos.x = love.math.random(-magnitude, magnitude) + default_position().x
        image_pos.y = love.math.random(-magnitude, magnitude) + default_position().y
        image_tween = tween.new(config.data.shake_lerp_speed, image_pos, default_position(), config.data.shake_type)
    end
end

function getFrame(amplitude)
    local frame = nil
    local lastTalk = timeMS() - talk_end_time

    if isSleeping then
        return frames.sleep
    end

    -- check for talk decay
    if lastTalk < config.data.decay_time then
        -- always update on scream since its highest state
        if amplitude > config.data.scream_threshold or talk_type == 1 then
            -- screaming
            frame = frames.scream
            talk_type = 1
            -- only update talk time if were still reaching the threshold
            if amplitude > config.data.scream_threshold then
                talk_end_time = timeMS() + config.data.decay_time
                updateShake(amplitude * config.data.scream_shake_scale)
            end
        elseif (amplitude > config.data.talk_threshold and amplitude < config.data.scream_threshold) or talk_type == 0 then
            -- if were not decaying screaming, update talk if needed
            -- talking
            frame = do_blink and frames.closed_open or frames.open_open
            talk_type = 0
            -- only update talk time if were still reaching the threshold
            if amplitude > config.data.talk_threshold then
                talk_end_time = timeMS() + config.data.decay_time
                updateShake(amplitude * config.data.shake_scale)
            end
        end
    else
        -- not decaying, update
        if amplitude > config.data.scream_threshold then
            -- screaming
            frame = frames.scream
            talk_end_time = timeMS() + config.data.decay_time
            talk_type = 1
            updateShake(amplitude * config.data.scream_shake_scale)
        elseif amplitude > config.data.talk_threshold then
            -- talking
            frame = do_blink and frames.closed_open or frames.open_open
            talk_end_time = timeMS() + config.data.decay_time
            talk_type = 0
            updateShake(amplitude * config.data.shake_scale)
        else
            -- quiet
            frame = do_blink and frames.closed_closed or frames.open_closed
        end
    end

    return frame
end

local combo = {value = 1, items = {'A', 'B', 'C'}}

function TestWindow()
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

function startSleepTween(start, ending)
    image_tween = tween.new(1000, start, ending, 'inOutQuad')
end

function love.update(dt)
    server:update()

    -- check preset selection
    if love.keyboard.isDown('lctrl') and love.keyboard.isDown('lshift') then
        for i = 9, 0, -1 do
            local slot = i

            if slot == 0 then slot = 10 end

            if love.keyboard.isDown(i) and config.slot ~= slot then
                config:change_slot(slot)
            end
        end
    end

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

    -- check for blinking
    do_blink = false

    if timeMS() - blink_time >= config.data.blink_delay then
        if love.math.random() * 100 <= config.data.blink_chance then
            -- we blink, add delay before we can blink again
            blink_end_time = timeMS() + config.data.blink_duration
            blink_time = timeMS() + config.data.blink_delay
            do_blink = true
        else
            -- we no blink, add delay before trying again
            blink_time = timeMS() + config.data.blink_delay * 2
        end
    end

    -- check if still blinking
    if do_blink == false and timeMS() - blink_end_time < config.data.blink_duration then
        do_blink = true
    end

    -- get current frame
    current_frame = getFrame(getAmplitude())

    -- easing
    local completedTween = false

    if image_tween ~= nil then
        completedTween = image_tween:update(dt * 1000) -- update image tween in msec
    end

    if isSleeping and (image_tween == nil or completedTween) then
        local tmp = {}

        if sleepDirection == 0 then
            tmp = copy_table(sleepEnd)
            sleepDirection = 1
        else
            tmp = copy_table(sleepStart)
            sleepDirection = 0
        end

        startSleepTween(image_pos, tmp)
    end

    -- update ui
    ui:frameBegin()

    MenuBar()
    SettingsWindow()

    if debug_open then
        DebugWindow()
    end

	ui:frameEnd()
end

function love.draw()
    love.graphics.setBackgroundColor(config.data.bg_color.r / 255, config.data.bg_color.g / 255, config.data.bg_color.b / 255, 0)
    love.graphics.draw(current_frame, image_pos.x, image_pos.y, 0, config.data.zoom, config.data.zoom)
    ui:draw()
end

function love.quit()
    server:stop()
    if microphone then
        microphone:stop()
    end
end

function love.keypressed(key, scancode, isrepeat)
    ui:keypressed(key, scancode, isrepeat)
end

function love.keyreleased(key, scancode)
	ui:keyreleased(key, scancode)
end

function love.mousepressed(x, y, button, istouch, presses)
	if not ui:mousepressed(x, y, button, istouch, presses) then
        -- start draging if not ui press and right click
        if button == 2 and not isSleeping then
            dragging = true
        end
    end
end

function love.mousereleased(x, y, button, istouch, presses)
	if not ui:mousereleased(x, y, button, istouch, presses) then
    end

    -- stop dragging on right click release
    -- we want this even if ui captures it so it doesnt get stuck dragging
    if button == 2 then
        dragging = false
    end
end

function love.mousemoved(x, y, dx, dy, istouch)
	if not ui:mousemoved(x, y, dx, dy, istouch) then
    end

    -- if not clicked on menu, drag menu
    if dragging then
        config.data.offsetx = config.data.offsetx + dx
        config.data.offsety = config.data.offsety + dy

        update_offsets()
    end
end

function love.textinput(text)
    ui:textinput(text)
end

function love.wheelmoved(x, y)
	if not ui:wheelmoved(x, y) then
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
