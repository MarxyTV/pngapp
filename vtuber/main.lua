local nuklear = require 'nuklear'
local soft = require 'lib.soft'
local Collection = require 'lib.lua-collections.collections'
local tick = require 'lib.tick'
local binser = require 'lib.binser'

local ui = nil

local default_config = {
    -- bound settings
    talk_threshold = 0.045,
    scream_threshold = 0.47,
    decay_time = 0.25,
    shake_scale = 15.0,
    scream_shake_scale = 25.0,
    shake_lerp_speed = 5.0,
    blink_chance = 0.25,
    blink_duration = 0.035,
    blink_delay = 0.25,
    -- stuff
    offsetx = 0,
    offsety = 0,
    zoom = 1,
    mic_index = 1,
    bg_color = {
        r = 0,
        g = 1,
        b = 0
    }
}

local config = nil

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
local debug_open = true

--
local config_name = 'pngapp.settings'

function saveConfig()
    -- TODO: error check
    love.filesystem.write(config_name, binser.serialize(config))
end

function copy(obj, seen)
    if type(obj) ~= 'table' then return obj end
    if seen and seen[obj] then return seen[obj] end
    local s = seen or {}
    local res = setmetatable({}, getmetatable(obj))
    s[obj] = res
    for k, v in pairs(obj) do res[copy(k, s)] = copy(v, s) end
    return res
end

function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

function resetConfig()
    config = default_config
    config.offsetx = (love.graphics.getWidth() / 2) - 256
    config.offsety = (love.graphics.getHeight() / 2) - 256
    image_x:set(config.offsetx, { reset = true })
    image_y:set(config.offsety, { reset = true })
end

function loadConfig()
    local str = love.filesystem.read(config_name)

    if str == nil then
        resetConfig()
        return
    end

    local saved_config, len = binser.deserialize(str)

    config = copy(saved_config[1])

    print(config.mic_index)
end

function love.load()
    loadConfig()

	ui = nuklear.newUI()

    -- load image frames
    frames.open_closed = love.graphics.newImage("images/eyes_open_mouth_closed.png")
    frames.open_open = love.graphics.newImage("images/eyes_open_mouth_open.png")
    frames.closed_closed = love.graphics.newImage("images/eyes_closed_mouth_closed.png")
    frames.closed_open = love.graphics.newImage("images/eyes_closed_mouth_open.png")
    frames.scream = love.graphics.newImage("images/scream.png")

    microphone = love.audio.getRecordingDevices()[config.mic_index]
    microphone:start() -- start listening to mic

    image_x = soft:new(config.offsetx) -- used to ease shake
    image_x:setSpeed(config.shake_lerp_speed)
    image_y = soft:new(config.offsety) -- used to ease shake
    image_y:setSpeed(config.shake_lerp_speed)

    tick.framerate = 30

    love.graphics.setBackgroundColor(config.bg_color.r, config.bg_color.g, config.bg_color.b)
end

function MenuBar()
    if ui:windowBegin('MenuBar', 0, 0, 1920, 25, 'background') then
        ui:layoutRow('static', 20, 30, 2)
        if ui:menuBegin('File', 'none', 150, 200) then
            ui:layoutRow('dynamic', 20, 1)
            if ui:button('Save') then
                saveConfig()
            end
            if ui:button('Load Defaults') then
                resetConfig()
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
    if ui:windowBegin('Settings', 10, 35, 320, 480,
            'border', 'title', 'movable', 'scalable') then

        config.talk_threshold = sliderElement('Talk Threshold', 0, config.talk_threshold, config.scream_threshold, 0.001, 3)
        config.scream_threshold = sliderElement('Scream Threshold', config.talk_threshold, config.scream_threshold, 2, 0.001, 3)
        config.decay_time = sliderElement('Talk Decay', 0, config.decay_time, 1, 0.001, 3)

        config.shake_scale = sliderElement('Shake Scale', 0, config.shake_scale, 200, 0.5)
        config.scream_shake_scale = sliderElement('Scream Shake Scale', 0, config.scream_shake_scale, 200, 0.5)
        config.shake_lerp_speed = sliderElement('Shake Lerp Speed', 0.01, config.shake_lerp_speed, 20, 1)

        config.blink_chance = sliderElement('Blink Chance', 0, config.blink_chance, 1, 0.01, 2)
        config.blink_duration = sliderElement('Blink Duration', 0.001, config.blink_duration, 4, 0.001, 3)
        config.blink_delay = sliderElement('Blink Delay', 0.001, config.blink_delay, 4, 0.001, 3)
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
    image_x:set(love.math.random(-magnitude + config.offsetx, magnitude + config.offsetx), { reset = true })
    image_x:to(config.offsetx, { speed = config.shake_lerp_speed })
    image_y:set(love.math.random(-magnitude + config.offsety, magnitude + config.offsety), { reset = true })
    image_y:to(config.offsety, { speed = config.shake_lerp_speed })
end

function getFrame(amplitude)
    local frame = nil
    local lastTalk = love.timer.getTime() - talk_end_time

    -- check for talk decay
    if lastTalk < config.decay_time then
        -- always update on scream since its highest state
        if amplitude > config.scream_threshold or talk_type == 1 then
            -- screaming
            frame = frames.scream
            talk_type = 1
            -- only update talk time if were still reaching the threshold
            if amplitude > config.scream_threshold then
                talk_end_time = love.timer.getTime() + config.decay_time
                updateShake(amplitude * config.scream_shake_scale)
            end
        elseif (amplitude > config.talk_threshold and amplitude < config.scream_threshold) or talk_type == 0 then
            -- if were not decaying screaming, update talk if needed
            -- talking
            frame = do_blink and frames.closed_open or frames.open_open
            talk_type = 0
            -- only update talk time if were still reaching the threshold
            if amplitude > config.talk_threshold then
                talk_end_time = love.timer.getTime() + config.decay_time
                updateShake(amplitude * config.shake_scale)
            end
        end
    else
        -- not decaying, update
        if amplitude > config.scream_threshold then
            -- screaming
            frame = frames.scream
            talk_end_time = love.timer.getTime() + config.decay_time
            talk_type = 1
            updateShake(amplitude * config.scream_shake_scale)
        elseif amplitude > config.talk_threshold then
            -- talking
            frame = do_blink and frames.closed_open or frames.open_open
            talk_end_time = love.timer.getTime() + config.decay_time
            talk_type = 0
            updateShake(amplitude * config.shake_scale)
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

    if love.timer.getTime() - blink_time >= config.blink_delay then
        if love.math.random() <= config.blink_chance then
            -- we blink, add delay before we can blink again
            blink_end_time = love.timer.getTime() + config.blink_duration
            blink_time = love.timer.getTime() + config.blink_delay
            do_blink = true
        else
            -- we no blink, add delay before trying again
            blink_time = love.timer.getTime() + config.blink_delay * 2
        end
    end

    -- check if still blinking
    if do_blink == false and love.timer.getTime() - blink_end_time < config.blink_duration then
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
    love.graphics.draw(current_frame, image_x:get(), image_y:get(), 0, config.zoom, config.zoom)
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
        config.offsetx = config.offsetx + dx
        config.offsety = config.offsety + dy

        image_x:set(config.offsetx, { reset = true })
        image_y:set(config.offsety, { reset = true })
    end
end

function love.textinput(text)
	ui:textinput(text)
end

function love.wheelmoved(x, y)
	if not ui:wheelmoved(x, y) then
        if y ~= 0 then
            config.zoom = config.zoom + (y * 0.1)

            if config.zoom < 0.1 then
                config.zoom = 0.1
            end
        end
    end
end