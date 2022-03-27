local Collection = require 'lib.lua-collections.collections'
local tick = require 'lib.tick'
local soft = require 'lib.soft'

function love.load()
    frame_open_closed = love.graphics.newImage("images/eyes_open_mouth_closed.png")
    frame_open_open = love.graphics.newImage("images/eyes_open_mouth_open.png")
    frame_closed_closed = love.graphics.newImage("images/eyes_closed_mouth_closed.png")
    frame_closed_open = love.graphics.newImage("images/eyes_closed_mouth_open.png")
    frame_scream = love.graphics.newImage("images/scream.png")

    mic = love.audio.getRecordingDevices()[1]
    mic:start()

    -- amplitude tracking
    amplitude = 0
    max_amplitude = 0
    min_amplitude = 1

    -- threshold settings
    scream_threshold = 0.47
    talk_threshold = 0.045
    decay_time = 0.25

    -- effects
    shake_scale = 15.0
    scream_shake_scale = 25.0
    shake_lerp_speed = 5.0

    -- tracking
    talk_type = 0 -- 0 - talk, 1 - scream
    talk_end_time = 0
    dx = soft:new(0)
    dy = soft:new(0)

    -- blink settings
    blink_chance = 0.26
    blink_duration = 0.035
    blink_delay = 0.25
    blink_time = 0
    blink_end_time = 0

    tick.framerate = 30
end

function love.update(dt)
    waveData = collect({})
    data = mic:getData()

    if data ~= nil then
        for i = 0, data:getSampleCount() - 1 do
            waveData:push(data:getSample(i))
        end
    end

    doBlink = false

    if love.timer.getTime() - blink_time >= blink_delay then
        if love.math.random() <= blink_chance then
            -- we blink, add delay before we can blink again
            blink_end_time = love.timer.getTime() + blink_duration
            blink_time = love.timer.getTime() + blink_delay
            doBlink = true
        else
            -- we no blink, add delay before trying again
            blink_time = love.timer.getTime() + blink_delay * 2
        end
    end

    -- check if still blinking
    if doBlink == false and love.timer.getTime() - blink_end_time < blink_duration then
        doBlink = true
    end

    -- ease coords
    soft:update(dt)
end

function getAmplitude()
    if waveData:count() <= 0 then
        return 0.0
    end

    return math.abs(waveData:min() - waveData:max())
end

function updateShake(magnitude)
    dx:set(love.math.random(-magnitude, magnitude), { reset = true })
    dx:to(0, { speed = shake_lerp_speed })
    dy:set(love.math.random(-magnitude, magnitude), { reset = true })
    dy:to(0, { speed = shake_lerp_speed })
end

function getFrame(amplitude, blink)
    local frame = nil
    local lastTalk = love.timer.getTime() - talk_end_time

    -- check for talk decay
    if lastTalk < decay_time then
        -- always update on scream since its highest state
        if amplitude > scream_threshold or talk_type == 1 then
            -- screaming
            frame = frame_scream
            talk_type = 1
            -- only update talk time if were still reaching the threshold
            if amplitude > scream_threshold then
                talk_end_time = love.timer.getTime() + decay_time
                updateShake(amplitude * scream_shake_scale)
            end
        elseif (amplitude > talk_threshold and amplitude < scream_threshold) or talk_type == 0 then
            -- if were not decaying screaming, update talk if needed
            -- talking
            frame = blink and frame_closed_open or frame_open_open
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
            frame = frame_scream
            talk_end_time = love.timer.getTime() + decay_time
            talk_type = 1
            updateShake(amplitude * scream_shake_scale)
        elseif amplitude > talk_threshold then
            -- talking
            frame = blink and frame_closed_open or frame_open_open
            talk_end_time = love.timer.getTime() + decay_time
            talk_type = 0
            updateShake(amplitude * shake_scale)
        else
            -- quiet
            frame = blink and frame_closed_closed or frame_open_closed
        end

    end

    return frame
end

function love.draw()
    amp = getAmplitude()

    if (amp > max_amplitude) then
        max_amplitude = amp
    end

    if (amp < min_amplitude) then
        min_amplitude = amp
    end

    love.graphics.clear(0, 1, 0)
    love.graphics.draw(getFrame(amp, doBlink), dx:get(), dy:get())

    -- love.graphics.print("X, Y:" .. dx:get() .. ", " .. dy:get(), 0, 0)
end

function love.quit()
    mic:stop()
end