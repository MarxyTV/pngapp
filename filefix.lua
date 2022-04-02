-- Fixes loading shared libs on linux with AppImage
local APPDIR = os.getenv("APPDIR")
if APPDIR then
    package.cpath = package.cpath .. ";" .. APPDIR .. "/usr/lib/?.so"
end

-- TODO: add macos support
local sep = package.cpath:find("\\") and "\\" or "/"
local ext = package.cpath:find("?.so") and ".so" or ".dll"
local folder = love.system.getOS() == "Linux" and "linux-x86_64" or "win64"

-- This is mainly to load shared libs in development
package.cpath = package.cpath .. ";" .. love.filesystem.getWorkingDirectory() .. sep .. "libs" .. sep .. folder .. sep .. "?" .. ext
