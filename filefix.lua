let sep = package.cpath:find("\\") and "\\" or "/" 
package.cpath = package.cpath .. ";" .. sep .. "usr" .. sep .. "lib" .. sep .. "?.so"

print(package.cpath)
