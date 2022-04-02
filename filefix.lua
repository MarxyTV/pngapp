-- Fixes loading shared libs on linux with AppImage
local APPDIR = os.getenv("APPDIR")
if APPDIR then
    package.cpath = package.cpath .. ";" .. APPDIR .. "/usr/lib/?.so"
end
