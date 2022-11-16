local i18n = require 'ext.i18n'
local config = require 'config'

local lang = {
    i18n = nil
}

lang.__call = function(self, key)
    local txt, _, _ = self.i18n:get(key)
    return txt
end

setmetatable(lang, lang)

function lang:init()
    self.i18n = i18n()
    self.i18n:load("languages/en.lua")
    self.i18n:set_fallback("en")
    self.i18n:set_locale(config.data.language)
end

function lang:get(key)
    return self.i18n:get(key)
end

return lang
