local i18n = require 'ext.i18n'
local config = require 'config'
local Collections = require 'lua-collections.collections'

local lang = {
    i18n = nil,
}

lang.__call = function(self, key)
    local txt, _, _ = self.i18n:get(key)
    return txt
end

setmetatable(lang, lang)

function lang:init()
    self.i18n = i18n()

    local base = "languages"
    for _, path in ipairs(love.filesystem.getDirectoryItems(base)) do
        self.i18n:load(string.format("%s/%s", base, path))
    end

    self.i18n:set_fallback("en")
    self.i18n:set_locale(config.data.language)
end

function lang:get(key)
    return self.i18n:get(key)
end

function lang:get_locales()
    local list = collect({})
    for key, value in pairs(self.i18n.strings) do
        list:push(key)
    end

    return list:all()
end

function lang:set_locale(key)
    config.data.language = key
    self.i18n:set_locale(key)
end

return lang
