local socket = require 'socket'
require 'utility'

local webhook = {
    server = nil
}

setmetatable(webhook, webhook)

function webhook:start(port)
    if self.server ~= nil then
        print('Error: tried to start tcp server when server ~= nil')
        return
    end

    self.server = socket.try(socket.bind('*', port))

    self.server:settimeout(0)

    local boundIP, boundPort = self.server:getsockname()

    print('Started tcp server on ' .. boundIP .. ':' .. boundPort)
end

function webhook:update()
    local client = self.server:accept()

    if client ~= nil then
        local data, err = client:receive()

        if err then
            print('TCP Error: ' .. err)
            return nil
        end

        data = data:gsub('[%p%c%s]', '')

        print('Received: ' .. data)
        client:close()
        return data
    end

    return nil
end

function webhook:stop()
    self.server:close()
    print('Stopped tcp server')
end

return webhook