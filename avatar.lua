local Camera = require 'ext.hump.camera'
local tween = require 'ext.tween'

local config = require 'config'
local audio = require 'audio'

local avatar = {
    camera = nil,
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
    self.tween = nil
    self.position.x = config.data.offsetx
    self.position.y = config.data.offsety
end

function avatar:sleepToggle()
    self.isSleeping = not self.isSleeping

    if self.isSleeping then
        local tmpPos = default_position()
        tmpPos.y = tmpPos.y - config.data.sleep_distance
        self.position = default_position()
        self.position.y = self.position.y + config.data.sleep_distance
        self.sleepDirection = 0
        self:startSleep(tmpPos)
        self.sleepStart = copy_table(tmpPos)
        self.sleepEnd = copy_table(self.position)
    else
        self.tween = nil
        self:update_offsets()
    end
end

function avatar:startSleep(endPosition)
    self.tween = tween.new(config.data.sleep_lerp_speed, self.position, endPosition, 'inOutQuad')
end

function avatar:updateShake(mag)
    local t = love.timer.getTime() * 1000

    if t - self.shake_end_time > config.data.shake_delay then
        self.shake_end_time = t + config.data.shake_delay
        self.position.x = love.math.random(-mag, mag) + default_position().x
        self.position.y = love.math.random(-mag, mag) + default_position().y
        self.tween = tween.new(config.data.shake_lerp_speed, self.position, default_position(),
            config.data.shake_type)
    end
end

-- determines which image frame we should use
function avatar:getFrame(amplitude)
    local frame = nil
    local lastTalk = timeMS() - self.talk_end_time

    if self.isSleeping then
        return self.frames.sleep
    end

    -- check for talk decay
    if lastTalk < config.data.decay_time then
        -- always update on scream since its highest state
        if (amplitude > config.data.scream_threshold or self.talk_type == 1) and config.data.scream_enabled and
            config.data.talk_enabled
        then
            -- screaming
            frame = self.frames.scream
            self.talk_type = 1
            -- only update talk time if were still reaching the threshold
            if amplitude > config.data.scream_threshold then
                self.talk_end_time = timeMS() + config.data.decay_time
                if config.data.shake_enabled then
                    self:updateShake(amplitude * config.data.scream_shake_scale)
                end
            end
        elseif amplitude > config.data.talk_threshold or self.talk_type == 0 then
            -- if were not decaying screaming, update talk if needed
            -- talking
            if config.data.talk_enabled then
                frame = self.do_blink and self.frames.closed_open or self.frames.open_open
            else
                frame = self.do_blink and self.frames.closed_closed or self.frames.open_closed
            end
            self.talk_type = 0
            -- only update talk time if were still reaching the threshold
            if amplitude > config.data.talk_threshold then
                self.talk_end_time = timeMS() + config.data.decay_time
                if config.data.shake_enabled then
                    self:updateShake(amplitude * config.data.shake_scale)
                end
            end
        end
    else
        -- not decaying, update
        if amplitude > config.data.scream_threshold and config.data.scream_enabled then
            -- screaming
            frame = self.frames.scream
            self.talk_end_time = timeMS() + config.data.decay_time
            self.talk_type = 1
            if config.data.shake_enabled then
                self:updateShake(amplitude * config.data.scream_shake_scale)
            end
        elseif amplitude > config.data.talk_threshold then
            -- talking
            if config.data.talk_enabled then
                frame = self.do_blink and self.frames.closed_open or self.frames.open_open
            else
                frame = self.do_blink and self.frames.closed_closed or self.frames.open_closed
            end
            self.talk_end_time = timeMS() + config.data.decay_time
            self.talk_type = 0
            if config.data.shake_enabled then
                self:updateShake(amplitude * config.data.shake_scale)
            end
        else
            -- quiet
            frame = self.do_blink and self.frames.closed_closed or self.frames.open_closed
        end
    end

    return frame
end

function avatar:init()
    self.frames.open_closed = config:get_image('open_closed')
    self.frames.open_open = config:get_image('open_open')
    self.frames.closed_closed = config:get_image('closed_closed')
    self.frames.closed_open = config:get_image('closed_open')
    self.frames.scream = config:get_image('scream')
    self.frames.sleep = config:get_image('sleep')
    self.position = default_position();
    self.camera = Camera(self.position.x, self.position.y)
end

function avatar:reload_frame(key)
    avatar.frames[key] = config:get_image(key)
end

function avatar:checkBlink()
    if timeMS() - self.blink_time >= config.data.blink_delay then
        if love.math.random() * 100 <= config.data.blink_chance then
            -- we blink, add delay before we can blink again
            self.blink_end_time = timeMS() + config.data.blink_duration
            self.blink_time = timeMS() + config.data.blink_delay
            self.do_blink = true
        else
            -- we no blink, add delay before trying again
            self.blink_time = timeMS() + config.data.blink_delay * 2
        end
    end

    -- check if still blinking
    if self.do_blink == false and timeMS() - self.blink_end_time < config.data.blink_duration then
        self.do_blink = true
    end
end

function avatar:update(dt)
    self.do_blink = false

    if config.data.blink_enabled then
        self:checkBlink()
    end

    -- get current frame
    self.current_frame = self:getFrame(audio:getMicAmplitude())

    -- easing
    local completedTween = false

    if self.tween ~= nil then
        completedTween = self.tween:update(dt * 1000) -- update image tween in msec
    end

    -- reverse direction so avatar bobs
    if self.isSleeping and (self.tween == nil or completedTween) then
        local tmp = {}

        if self.sleepDirection == 0 then
            tmp = copy_table(self.sleepEnd)
            self.sleepDirection = 1
        else
            tmp = copy_table(self.sleepStart)
            self.sleepDirection = 0
        end

        self:startSleep(tmp)
    end

    -- camera
    local dx, dy = self.position.x - self.camera.x, self.position.y - self.camera.y
    self.camera:move(dx, dy)
    self.camera:zoomTo(config.data.zoom)
end

function avatar:draw()
    self.camera:attach()
    local frame = self.current_frame == nil and self.frames.open_closed or self.current_frame

    if frame ~= nil then
        love.graphics.draw(frame,
            love.graphics.getWidth() / 2,
            love.graphics.getHeight() / 2,
            0)
    end
    self.camera:detach()
end

function avatar:shutdown()
end

return avatar
