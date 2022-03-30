local nuklear = require 'nuklear'
local soft = require 'lib.soft'
local Collection = require 'lib.lua-collections.collections'
local tick = require 'lib.tick'
local binser = require 'lib.binser'

local config = require 'config'

require 'utility'

local ui = nil

-- tracking
local talk_type = 0
local talk_end_time = 0
local blink_time = 0
local blink_end_time = 0
local do_blink = false
local wave_data = nil
local current_frame = nil
local image_x = nil
local image_y = nil

-- stuff
local microphone = nil
local frames = {
    open_closed = nil,
    open_open = nil,
    closed_closed = nil,
    closed_open = nil,
    scream = nil
}

-- ui stuff
local dragging = false
local settings_open = true
local debug_open = false

function love.load()
    config:load('pngapp')

	ui = nuklear.newUI()

    -- load image frames
    frames.open_closed = love.graphics.newImage("images/eyes_open_mouth_closed.png")
    frames.open_open = love.graphics.newImage("images/eyes_open_mouth_open.png")
    frames.closed_closed = love.graphics.newImage("images/eyes_closed_mouth_closed.png")
    frames.closed_open = love.graphics.newImage("images/eyes_closed_mouth_open.png")
    frames.scream = love.graphics.newImage("images/scream.png")

    microphone = love.audio.getRecordingDevices()[config.data.mic_index]
    microphone:start() -- start listening to mic

    image_x = soft:new(config.data.offsetx) -- used to ease shake
    image_x:setSpeed(config.data.shake_lerp_speed)
    image_y = soft:new(config.data.offsety) -- used to ease shake
    image_y:setSpeed(config.data.shake_lerp_speed)

    tick.framerate = 30
end

function MenuBar()
    if ui:windowBegin('MenuBar', 0, 0, 1920, 25, 'background') then
        ui:layoutRow('static', 20, 30, 2)
        if ui:menuBegin('File', 'none', 150, 200) then
            ui:layoutRow('dynamic', 20, 1)
            if ui:button('Save') then
                config:save('pngapp')
            end
            if ui:button('Load Defaults') then
                config:reset()
                image_x:set(config.data.offsetx, { reset = true })
                image_y:set(config.data.offsety, { reset = true })
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
            end

            if ui:button(debug_open and 'Hide Debug Menu' or 'Show Debug Menu') then
                debug_open = not debug_open

                if debug_open then
                    ui:windowShow('Debug')
                else
                    ui:windowHide('Debug')
                end
            end
        end
        ui:menuEnd()
    end

    ui:windowEnd()
end

function sliderElement(label, min, current, max, step, decimals)
    ui:layoutRow('dynamic', 20, 2)
    ui:label(label)
    ui:label(round(current, decimals), 'right')
    ui:layoutRow('dynamic', 20, 1)
    return ui:slider(min, current, max, step)
end

function SettingsWindow()
    if ui:windowBegin('Settings', 10, 35, 320, 480,
            'border', 'title', 'movable', 'scalable') then

        config.data.talk_threshold = sliderElement('Talk Threshold', 0, config.data.talk_threshold, config.data.scream_threshold, 0.001, 3)
        config.data.scream_threshold = sliderElement('Scream Threshold', config.data.talk_threshold, config.data.scream_threshold, 2, 0.001, 3)
        config.data.decay_time = sliderElement('Talk Decay', 0, config.data.decay_time, 1, 0.001, 3)

        config.data.shake_scale = sliderElement('Shake Scale', 0, config.data.shake_scale, 200, 0.5)
        config.data.scream_shake_scale = sliderElement('Scream Shake Scale', 0, config.data.scream_shake_scale, 200, 0.5)
        config.data.shake_lerp_speed = sliderElement('Shake Lerp Speed', 0.01, config.data.shake_lerp_speed, 20, 1)

        config.data.blink_chance = sliderElement('Blink Chance', 0, config.data.blink_chance, 1, 0.01, 2)
        config.data.blink_duration = sliderElement('Blink Duration', 0.001, config.data.blink_duration, 4, 0.001, 3)
        config.data.blink_delay = sliderElement('Blink Delay', 0.001, config.data.blink_delay, 4, 0.001, 3)

        -- ui:layoutRow('dynamic', 20, 1)
        -- ui:label('Background Color')
        -- ui:layoutRow('dynamic', 150, 2)
        -- config.data.bg_color = ui:colorPicker(config.data.bg_color)
    end

    ui:windowEnd()
end

function DebugWindow()
    if ui:windowBegin('Debug', 350, 35, 200, 200,
            'border', 'title', 'movable', 'scalable') then

        ui:layoutRow('dynamic', 50, 1)
        ui:label(string.format('Amplitude: %.3f', getAmplitude()))
    end
    ui:windowEnd()
end

function getAmplitude()
    if wave_data == nil or wave_data:count() <= 0 then
        return 0
    end

    return math.abs(wave_data:min() - wave_data:max())
end

function updateShake(magnitude)
    image_x:set(love.math.random(-magnitude + config.data.offsetx, magnitude + config.data.offsetx), { reset = true })
    image_x:to(config.data.offsetx, { speed = config.data.shake_lerp_speed })
    image_y:set(love.math.random(-magnitude + config.data.offsety, magnitude + config.data.offsety), { reset = true })
    image_y:to(config.data.offsety, { speed = config.data.shake_lerp_speed })
end

function getFrame(amplitude)
    local frame = nil
    local lastTalk = love.timer.getTime() - talk_end_time

    -- check for talk decay
    if lastTalk < config.data.decay_time then
        -- always update on scream since its highest state
        if amplitude > config.data.scream_threshold or talk_type == 1 then
            -- screaming
            frame = frames.scream
            talk_type = 1
            -- only update talk time if were still reaching the threshold
            if amplitude > config.data.scream_threshold then
                talk_end_time = love.timer.getTime() + config.data.decay_time
                updateShake(amplitude * config.data.scream_shake_scale)
            end
        elseif (amplitude > config.data.talk_threshold and amplitude < config.data.scream_threshold) or talk_type == 0 then
            -- if were not decaying screaming, update talk if needed
            -- talking
            frame = do_blink and frames.closed_open or frames.open_open
            talk_type = 0
            -- only update talk time if were still reaching the threshold
            if amplitude > config.data.talk_threshold then
                talk_end_time = love.timer.getTime() + config.data.decay_time
                updateShake(amplitude * config.data.shake_scale)
            end
        end
    else
        -- not decaying, update
        if amplitude > config.data.scream_threshold then
            -- screaming
            frame = frames.scream
            talk_end_time = love.timer.getTime() + config.data.decay_time
            talk_type = 1
            updateShake(amplitude * config.data.scream_shake_scale)
        elseif amplitude > config.data.talk_threshold then
            -- talking
            frame = do_blink and frames.closed_open or frames.open_open
            talk_end_time = love.timer.getTime() + config.data.decay_time
            talk_type = 0
            updateShake(amplitude * config.data.shake_scale)
        else
            -- quiet
            frame = do_blink and frames.closed_closed or frames.open_closed
        end
    end

    return frame
end

function love.update(dt)
    -- get mic data
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

    if love.timer.getTime() - blink_time >= config.data.blink_delay then
        if love.math.random() <= config.data.blink_chance then
            -- we blink, add delay before we can blink again
            blink_end_time = love.timer.getTime() + config.data.blink_duration
            blink_time = love.timer.getTime() + config.data.blink_delay
            do_blink = true
        else
            -- we no blink, add delay before trying again
            blink_time = love.timer.getTime() + config.data.blink_delay * 2
        end
    end

    -- check if still blinking
    if do_blink == false and love.timer.getTime() - blink_end_time < config.data.blink_duration then
        do_blink = true
    end

    -- get current frame
    current_frame = getFrame(getAmplitude())

    -- ease coords
    soft:update(dt)

    -- update ui
    ui:frameBegin()

    MenuBar()
    SettingsWindow()
    DebugWindow()

	ui:frameEnd()
end

function love.draw()
    local r, g, b = nuklear.colorParseRGBA(config.data.bg_color)
    love.graphics.setBackgroundColor(r / 255, g / 255, b / 255)
    love.graphics.draw(current_frame, image_x:get(), image_y:get(), 0, config.data.zoom, config.data.zoom)
    ui:draw()
end

function love.quit()
    microphone:stop()
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
        if button == 2 then
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

        image_x:set(config.data.offsetx, { reset = true })
        image_y:set(config.data.offsety, { reset = true })
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