local Collection = require 'ext.lua-collections.collections'
local config = require 'config'

local audio = {
    microphone = nil,
    inputData = nil,

    max_amplitude = 0
}

setmetatable(audio, audio)

function audio:init()
    audio.microphone = love.audio.getRecordingDevices()[config.data.mic_index]

    if audio.microphone ~= nil then
        audio.microphone:start() -- start listening to mic
    end
end

function audio:update(dt)
    -- update mic data
    if audio.microphone ~= nil then
        local mic_buffer = audio.microphone:getData()

        audio.inputData = collect({})

        if mic_buffer ~= nil then
            -- sample data starts at index 0
            for i = 0, mic_buffer:getSampleCount() - 1 do
                audio.inputData:push(mic_buffer:getSample(i))
            end
        end
    end
end

function audio:shutdown()
end

function audio:getMicAmplitude()
    if audio.inputData == nil or audio.inputData:count() <= 0 then
        return 0
    end

    local value = math.abs(audio.inputData:min() - audio.inputData:max())

    -- this is really only used for debuging
    if value > audio.max_amplitude then
        audio.max_amplitude = value
    end

    return value
end

function audio:setMicrophone(device)
    if audio.microphone then
        audio.microphone:stop()
    end

    audio.microphone = device
    audio.microphone:start()
end

return audio
