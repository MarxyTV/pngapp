-- TODO: add macos support
local sep = package.cpath:find("\\") and "\\" or "/"
local ext = package.cpath:find("?.so") and ".so" or ".dll"
local myOS = love.system.getOS()
local folder = "win64"

if myOS == "Linux" then
    folder = "linux-x86_64"
elseif myOS == "OS X" then
    folder = "macos-x86_64"
end

-- Fixes loading shared libs on linux with AppImage
local APPDIR = os.getenv("APPDIR")
if APPDIR then
    package.cpath = package.cpath .. ";" .. APPDIR .. "/usr/lib/?.so"
end

function addPath(path)
    if path ~= nil then
        package.cpath = package.cpath .. ";" .. path .. sep .. "libs" .. sep .. folder .. sep .. "?" .. ext
    end
end

addPath(love.filesystem.getWorkingDirectory())
addPath(love.filesystem.getAppdataDirectory())
addPath(love.filesystem.getUserDirectory())
addPath(love.filesystem.getSourceBaseDirectory())
addPath(arg[1])

love.filesystem.setRequirePath(love.filesystem.getRequirePath() .. ';ext/?.lua')
