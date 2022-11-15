local audio = require 'audio'

local DebugMenu = {

}

setmetatable(DebugMenu, DebugMenu)

function DebugMenu:init()
end

function DebugMenu:update(ui)
    if ui:windowBegin('Debug', 360, 25, 200, 200,
        'border', 'title', 'movable', 'scalable') then

        ui:layoutRow('dynamic', 50, 1)
        ui:label(string.format('Amplitude: %.3f', audio:getMicAmplitude()))
        ui:label(string.format('Max Amplitude: %.3f', audio.max_amplitude))
    end
    ui:windowEnd()
end

return DebugMenu
