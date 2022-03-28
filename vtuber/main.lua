local nuklear = require 'nuklear'
local soft = require 'lib.soft'
local Collection = require 'lib.lua-collections.collections'
local tick = require 'lib.tick'

local ui = nil

-- bound settings
local talk_threshold = 0.045
local scream_threshold = 0.47
local decay_time = 0.25
local shake_scale = 15.0
local scream_shake_scale = 25.0
local shake_lerp_speed = 5.0
local blink_chance = 0.25
local blink_duration = 0.035
local blink_delay = 0.25

-- tracking
local talk_type = 0
local talk_end_time = 0
local blink_time = 0
local blink_end_time = 0
local do_blink = false
local wave_data = nil
local current_frame = nil
local dx = nil
local dy = nil

-- stuff
local microphone = nil
local frames = {
    open_closed = nil,
    open_open = nil,
    closed_closed = nil,
    closed_open = nil,
    scream = nil
}

function love.load()
	ui = nuklear.newUI()

    -- load image frames
    frames.open_closed = love.graphics.newImage("images/eyes_open_mouth_closed.png")
    frames.open_open = love.graphics.newImage("images/eyes_open_mouth_open.png")
    frames.closed_closed = love.graphics.newImage("images/eyes_closed_mouth_closed.png")
    frames.closed_open = love.graphics.newImage("images/eyes_closed_mouth_open.png")
    frames.scream = love.graphics.newImage("images/scream.png")

    microphone = love.audio.getRecordingDevices()[1]
    microphone:start() -- start listening to mic

    dx = soft:new(0) -- used to ease shake
    dy = soft:new(0) -- used to ease shake

    tick.framerate = 30

    love.graphics.setBackgroundColor(0, 1, 0)
end

function MenuBar()
    if ui:windowBegin('MenuBar', 0, 0, 1920, 25, 'background') then
        ui:layoutRow('dynamic', 20, 1)
        if ui:menuBegin('File', 'none', 150, 200) then
            ui:layoutRow('dynamic', 20, 1)
            if ui:button('Quit') then
                love.event.quit()
            end
        end
        ui:menuEnd()
    end

    ui:windowEnd()
end

function round(v, d)
    local mult = math.pow(10, d or 0) -- round to 0 places when d not supplied
    return math.floor(v * mult + 0.5) / mult
end

function sliderElement(label, min, current, max, step, decimals)
    ui:layoutRow('dynamic', 20, 2)
    ui:label(label)
    ui:label(round(current, decimals), 'right')
    ui:layoutRow('dynamic', 20, 1)
    return ui:slider(min, current, max, step)
end

function SettingsWindow()
    if ui:windowBegin('Settings', 950, 35, 320, 480,
            'border', 'title', 'movable', 'scalable') then

        talk_threshold = sliderElement('Talk Threshold', 0, talk_threshold, scream_threshold, 0.001, 3)
        scream_threshold = sliderElement('Scream Threshold', talk_threshold, scream_threshold, 2, 0.001, 3)
        decay_time = sliderElement('Talk Decay', 0, decay_time, 1, 0.001, 3)

        shake_scale = sliderElement('Shake Scale', 0, shake_scale, 200, 0.5)
        scream_shake_scale = sliderElement('Scream Shake Scale', 0, scream_shake_scale, 200, 0.5)
        shake_lerp_speed = sliderElement('Shake Lerp Speed', 0.01, shake_lerp_speed, 20, 1)

        blink_chance = sliderElement('Blink Chance', 0, blink_chance, 1, 0.01, 2)
        blink_duration = sliderElement('Blink Duration', 0.001, blink_duration, 4, 0.001, 3)
        blink_delay = sliderElement('Blink Delay', 0.001, blink_delay, 4, 0.001, 3)
    end

    ui:windowEnd()
end

function DebugWindow()
    if ui:windowBegin('Debug', 740, 35, 200, 200,
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
    dx:set(love.math.random(-magnitude, magnitude), { reset = true })
    dx:to(0, { speed = shake_lerp_speed })
    dy:set(love.math.random(-magnitude, magnitude), { reset = true })
    dy:to(0, { speed = shake_lerp_speed })
end

function getFrame(amplitude)
    local frame = nil
    local lastTalk = love.timer.getTime() - talk_end_time

    -- check for talk decay
    if lastTalk < decay_time then
        -- always update on scream since its highest state
        if amplitude > scream_threshold or talk_type == 1 then
            -- screaming
            frame = frames.scream
            talk_type = 1
            -- only update talk time if were still reaching the threshold
            if amplitude > scream_threshold then
                talk_end_time = love.timer.getTime() + decay_time
                updateShake(amplitude * scream_shake_scale)
            end
        elseif (amplitude > talk_threshold and amplitude < scream_threshold) or talk_type == 0 then
            -- if were not decaying screaming, update talk if needed
            -- talking
            frame = do_blink and frames.closed_open or frames.open_open
            talk_type = 0
            -- only update talk time if were still reaching the threshold
            if amplitude > talk_threshold then
                talk_end_time = love.timer.getTime() + decay_time
                updateShake(amplitude * shake_scale)
            end
        end
    else
        -- not decaying, update
        if amplitude > scream_threshold then
            -- screaming
            frame = frames.scream
            talk_end_time = love.timer.getTime() + decay_time
            talk_type = 1
            updateShake(amplitude * scream_shake_scale)
        elseif amplitude > talk_threshold then
            -- talking
            frame = do_blink and frames.closed_open or frames.open_open
            talk_end_time = love.timer.getTime() + decay_time
            talk_type = 0
            updateShake(amplitude * shake_scale)
        else
            -- quiet
            frame = do_blink and frames.closed_closed or frames.open_closed
        end
    end

    return frame
end

function love.update(dt)
    -- get mic data
    local mic_buffer = microphone:getData()

    wave_data = collect({})

    if mic_buffer ~= nil then
        -- sample data starts at index 0
        for i = 0, mic_buffer:getSampleCount() - 1 do
            wave_data:push(mic_buffer:getSample(i))
        end
    end

    -- check for blinking
    do_blink = false

    if love.timer.getTime() - blink_time >= blink_delay then
        if love.math.random() <= blink_chance then
            -- we blink, add delay before we can blink again
            blink_end_time = love.timer.getTime() + blink_duration
            blink_time = love.timer.getTime() + blink_delay
            do_blink = true
        else
            -- we no blink, add delay before trying again
            blink_time = love.timer.getTime() + blink_delay * 2
        end
    end

    -- check if still blinking
    if do_blink == false and love.timer.getTime() - blink_end_time < blink_duration then
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
    love.graphics.draw(current_frame, dx:get(), dy:get())
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
	ui:mousepressed(x, y, button, istouch, presses)
end

function love.mousereleased(x, y, button, istouch, presses)
	ui:mousereleased(x, y, button, istouch, presses)
end

function love.mousemoved(x, y, dx, dy, istouch)
	ui:mousemoved(x, y, dx, dy, istouch)
end

function love.textinput(text)
	ui:textinput(text)
end

function love.wheelmoved(x, y)
	ui:wheelmoved(x, y)
end