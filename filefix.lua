-- TODO: add macos support
local sep = package.cpath:find("\\") and "\\" or "/"
local ext = package.cpath:find("?.so") and ".so" or ".dll"
local folder = love.system.getOS() == "Linux" and "linux-x86_64" or "win64"

-- Fixes loading shared libs on linux with AppImage
local APPDIR = os.getenv("APPDIR")
if APPDIR then
    package.cpath = package.cpath .. ";" .. APPDIR .. "/usr/lib/?.so"
end

function addPath(path)
    package.cpath = package.cpath .. ";" .. path .. sep .. "libs" .. sep .. folder .. sep .. "?" .. ext
end

addPath(love.filesystem.getWorkingDirectory())
addPath(love.filesystem.getAppdataDirectory())
addPath(love.filesystem.getUserDirectory())
addPath(love.filesystem.getSourceBaseDirectory())
addPath(arg[1])

love.filesystem.setRequirePath(love.filesystem.getRequirePath() .. ';ext/?.lua')