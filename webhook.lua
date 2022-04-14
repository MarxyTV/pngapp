local ws = require 'ws'
require('utility')

local webhook = {
    server = nil,
    channel = nil
}

setmetatable(webhook, webhook)

function webhook:start(port)
    self.server = ws.newServer(port)
    self.channel = self.server:getChannel("^/websocket/?$")
    self.server:start()
    print('Started websocket server on port: ' .. port)
end

function webhook:update()
    local ev = self.channel:checkQueue()

    if ev then
        if ev.type == 'open' then
            print('Client connected')
        elseif ev.type == 'close' then
            print('Client disconnected')
        elseif ev.type == 'message' then
            local msg = ev.message:gsub('[%p%c%s]', '')
            print('Message: ' .. msg)
            print('test')
            self.channel:send(ev.connection, 'received')
            return msg
        end
    end

    return nil
end

function webhook:stop()
    if self.server then
        self.server:stop()
    end
end

return webhook