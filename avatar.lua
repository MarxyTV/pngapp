local config = require 'config'
local tween  = require 'ext.tween'

local avatar = {
    -- image frames
    frames = {
        open_closed = nil,
        open_open = nil,
        closed_closed = nil,
        closed_open = nil,
        scream = nil,
        sleep = nil
    },
    current_frame = nil,
    position = {
        x = 0,
        y = 0
    },
    tween = nil,
    -- sleep trackers
    sleepDirection = 0,
    isSleeping = false,
    sleepStart = 0,
    sleepEnd = 0,
    -- blink trackers
    do_blink = false,
    blink_time = 0,
    blink_end_time = 0,
    -- talk trackers
    talk_type = 0,
    talk_end_time = 0,
    shake_end_time = 0,
}

setmetatable(avatar, avatar)

local function default_position()
    return {
        x = config.data.offsetx or 0,
        y = config.data.offsety or 0
    }
end

function avatar:update_offsets()
    avatar.tween = nil
    avatar.position.x = config.data.offsetx
    avatar.position.y = config.data.offsety
end

function avatar:sleepToggle()
    avatar.isSleeping = not avatar.isSleeping

    if avatar.isSleeping then
        local tmpPos = default_position()
        tmpPos.y = tmpPos.y - 20
        avatar.position = default_position()
        avatar.position.y = avatar.position.y + 20
        avatar.sleepDirection = 0
        avatar:startSleep(tmpPos)
        avatar.sleepStart = copy_table(tmpPos)
        avatar.sleepEnd = copy_table(avatar.position)
    else
        avatar.tween = nil
        avatar:update_offsets()
    end
end

function avatar:startSleep(endPosition)
    avatar.tween = tween.new(1000, avatar.position, endPosition, 'inOutQuad')
end

function avatar:updateShake(mag)
    local t = love.timer.getTime() * 1000

    if t - avatar.shake_end_time > config.data.shake_delay then
        avatar.shake_end_time = t + config.data.shake_delay
        avatar.position.x = love.math.random(-mag, mag) + default_position().x
        avatar.position.y = love.math.random(-mag, mag) + default_position().y
        avatar.tween = tween.new(config.data.shake_lerp_speed, avatar.position, default_position(),
            config.data.shake_type)
    end
end

-- determines which image frame we should use
function avatar:getFrame(amplitude)
    local frame = nil
    local lastTalk = timeMS() - avatar.talk_end_time

    if avatar.isSleeping then
        return avatar.frames.sleep
    end

    -- check for talk decay
    if lastTalk < config.data.decay_time then
        -- always update on scream since its highest state
        if amplitude > config.data.scream_threshold or avatar.talk_type == 1 then
            -- screaming
            frame = avatar.frames.scream
            avatar.talk_type = 1
            -- only update talk time if were still reaching the threshold
            if amplitude > config.data.scream_threshold then
                avatar.talk_end_time = timeMS() + config.data.decay_time
                avatar:updateShake(amplitude * config.data.scream_shake_scale)
            end
        elseif (amplitude > config.data.talk_threshold and amplitude < config.data.scream_threshold) or
            avatar.talk_type == 0 then
            -- if were not decaying screaming, update talk if needed
            -- talking
            frame = avatar.do_blink and avatar.frames.closed_open or avatar.frames.open_open
            avatar.talk_type = 0
            -- only update talk time if were still reaching the threshold
            if amplitude > config.data.talk_threshold then
                avatar.talk_end_time = timeMS() + config.data.decay_time
                avatar:updateShake(amplitude * config.data.shake_scale)
            end
        end
    else
        -- not decaying, update
        if amplitude > config.data.scream_threshold then
            -- screaming
            frame = avatar.frames.scream
            avatar.talk_end_time = timeMS() + config.data.decay_time
            avatar.talk_type = 1
            avatar:updateShake(amplitude * config.data.scream_shake_scale)
        elseif amplitude > config.data.talk_threshold then
            -- talking
            frame = avatar.do_blink and avatar.rames.closed_open or avatar.frames.open_open
            avatar.talk_end_time = timeMS() + config.data.decay_time
            avatar.talk_type = 0
            avatar:updateShake(amplitude * config.data.shake_scale)
        else
            -- quiet
            frame = avatar.do_blink and avatar.frames.closed_closed or avatar.frames.open_closed
        end
    end

    return frame
end

function avatar:init()
    avatar.frames.open_closed = love.graphics.newImage("assets/eyes_open_mouth_closed.png")
    avatar.frames.open_open = love.graphics.newImage("assets/eyes_open_mouth_open.png")
    avatar.frames.closed_closed = love.graphics.newImage("assets/eyes_closed_mouth_closed.png")
    avatar.frames.closed_open = love.graphics.newImage("assets/eyes_closed_mouth_open.png")
    avatar.frames.scream = love.graphics.newImage("assets/scream.png")
    avatar.frames.sleep = love.graphics.newImage("assets/sleep.png")
    avatar.position = default_position();
end

function avatar:update(dt, micAmplitude)
    -- check for blinking
    avatar.do_blink = false

    if timeMS() - avatar.blink_time >= config.data.blink_delay then
        if love.math.random() * 100 <= config.data.blink_chance then
            -- we blink, add delay before we can blink again
            avatar.blink_end_time = timeMS() + config.data.blink_duration
            avatar.blink_time = timeMS() + config.data.blink_delay
            avatar.do_blink = true
        else
            -- we no blink, add delay before trying again
            avatar.blink_time = timeMS() + config.data.blink_delay * 2
        end
    end

    -- check if still blinking
    if avatar.do_blink == false and timeMS() - avatar.blink_end_time < config.data.blink_duration then
        avatar.do_blink = true
    end

    -- get current frame
    avatar.current_frame = avatar:getFrame(micAmplitude)

    -- easing
    local completedTween = false

    if avatar.tween ~= nil then
        completedTween = avatar.tween:update(dt * 1000) -- update image tween in msec
    end

    -- reverse direction so avatar bobs
    if avatar.isSleeping and (avatar.tween == nil or completedTween) then
        local tmp = {}

        if avatar.sleepDirection == 0 then
            tmp = copy_table(avatar.sleepEnd)
            avatar.sleepDirection = 1
        else
            tmp = copy_table(avatar.sleepStart)
            avatar.sleepDirection = 0
        end

        avatar:startSleep(tmp)
    end
end

function avatar:draw()
    love.graphics.draw(avatar.current_frame,
        avatar.position.x,
        avatar.position.y,
        0,
        config.data.zoom,
        config.data.zoom)
end

function avatar:shutdown()
end

return avatar
