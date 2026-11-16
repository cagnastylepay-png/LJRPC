local options = ...
local useGlobalToken = options == nil
if useGlobalToken then
 local environment = type(getgenv) == "function" and getgenv() or _G
 local token = environment.LJRPC_LUA_TOKEN or LJRPC_LUA_TOKEN
 assert(type(token) == "string" and #token >= 32, "Set the global LJRPC_LUA_TOKEN before running the loader")
 options = {
  Url = "wss://m4gix-ws.onrender.com/ljrpc/ws",
  Token = token,
  AllowEval = true,
 }
end
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
local rpc = chunk()
if useGlobalToken then
 rpc.Register("SmokePing", function() return "pong" end)
end
return rpc.Connect(options)
