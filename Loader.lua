local options = ...
assert(type(options) == "table", "Pass LJRPC connection options to the loader")
local source = options.Source
if not source and options.LocalPath then
 assert(type(readfile) == "function", "Local script access unavailable")
 source = readfile(options.LocalPath)
end
if not source then
 source = game:HttpGet(options.SourceUrl or "https://raw.githubusercontent.com/cagnastylepay-png/LJRPC/main/LJRPC.lua")
end
local chunk, reason = loadstring(source, "LJRPC")
assert(chunk, reason)
return chunk().Connect(options)
