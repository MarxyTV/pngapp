local pretty = require 'pl.pretty'
local Collection = require 'lua-collections.collections'
local audio = require 'audio'
local lang = require 'lang'
local config = require 'config'
local avatar = require 'avatar'

local SettingsMenu = require 'menus.Settings'

local open_delay = 1000

local ImageSelect = {
    dirLoaded = false,
    items = nil,
    openTimer = 0,
    refreshTimer = 0
}

setmetatable(ImageSelect, ImageSelect)

function ImageSelect:init()
    -- make sure we create our images folder
    -- TODO move this to filesystem setup when copying data
    if not love.filesystem.createDirectory('images') then
        print('Error creating images directory')
    end
end

function ImageSelect:updateFiles()
    local files = love.filesystem.getDirectoryItems('images')

    -- todo close old images?
    self.items = collect({})

    for _, value in ipairs(files) do
        local filePath = 'images/' .. value
        local info = love.filesystem.getInfo(filePath)
        if info and info.type == "file" then
            local file = love.filesystem.newFileData(filePath)
            self.items:push({
                icon = love.graphics.newImage(file),
                name = value
            })
        end
    end
end

function ImageSelect:update(ui)
    if not self.dirLoaded then
        self:updateFiles()
        self.dirLoaded = true
    end

    if ui:windowBegin('Image Select', 360, 25, 640, 460,
        'border', 'scrollbar') then

        ui:layoutRow('dynamic', 20, 7)
        if ui:button(lang('ui/openfolder')) then
            if timeMS() - self.openTimer >= open_delay then
                self.openTimer = timeMS() + open_delay
                if love.system.getOS() == "Windows" then
                    os.execute('start ' .. love.filesystem.getSaveDirectory())
                else
                    os.execute('open ' .. love.filesystem.getSaveDirectory() .. ' &')
                end
            end
        end

        if ui:button(lang('ui/refresh')) then
            self.dirLoaded = false
        end

        if ui:button(lang('ui/clear')) then
            config:set_image(SettingsMenu.imageKey, nil)
            avatar:reload_frame(SettingsMenu.imageKey)
        end

        ui:spacing(1)
        ui:label(SettingsMenu.imageKey)
        ui:spacing(1)

        if ui:button('X') then
            SettingsMenu.openImageSelect = false
            SettingsMenu.imageKey = nil
        end

        ui:layoutRow('static', 200, 200, 3)
        self.items:eachi(function(index, value)
            if ui:button(nil, value.icon) then
                config:set_image(SettingsMenu.imageKey, 'images/' .. value.name)
                avatar:reload_frame(SettingsMenu.imageKey)
            end
        end)
    end
    ui:windowEnd()
end

return ImageSelect
