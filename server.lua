local socket = require 'socket'
local JSON = require 'ext.json-lua.JSON'
local Signal = require 'ext.hump.signal'
require 'utility'

local tcpSocket = nil
local server = {}

setmetatable(server, server)

function server:start(port)
    if tcpSocket ~= nil then
        print('Error: tried to start tcp server when tcpSocket ~= nil')
        return
    end

    tcpSocket = socket.try(socket.bind('*', port))

    tcpSocket:settimeout(0)

    local boundIP, boundPort = tcpSocket:getsockname()

    print('Started tcp server ' .. boundIP .. ':' .. boundPort)
end

function server:update()
    local client = tcpSocket:accept()

    if client ~= nil then
        local data, err = client:receive()

        if err then
            print('TCP Error: ' .. err)
            return
        end

        client:close()

        -- parse the data

        -- data = data:gsub('[%p%c%s]', '') -- remove escape sequences

        print('Received: ' .. data)

        local command = JSON:decode(data)

        print(dump(command))

        Signal.emit(command.name, command.args)
    end
end

function server:stop()
    tcpSocket:close()
    print('Stopped tcp server')
end

return server