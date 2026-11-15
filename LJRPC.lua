local Http = game:GetService("HttpService")
local LJRPC = {}
local methods = {}
local socket

function LJRPC.Register(name, callback)
 assert(type(name) == "string" and type(callback) == "function")
 methods[name] = callback
end

local instances = {}
local handles = {}
local handleCount = 0

function LJRPC.ConnectionGuard()
 local connection = socket
 return function() return socket == connection end
end

local function expose(instance)
 local id = handles[instance]
 if not id then
  assert(handleCount < 512, "Object reference limit reached")
  id = Http:GenerateGUID(false)
  handles[instance], instances[id] = id, instance
  handleCount += 1
 end
 return { ["$ref"] = id }
end

LJRPC.Register("Release", function(id)
 local instance = instances[id]
 if not instance then return false end
 instances[id], handles[instance] = nil, nil
 handleCount -= 1
 return true
end)

local function resetHandles()
 table.clear(instances)
 table.clear(handles)
 handleCount = 0
end

local function invoke(callback, params, count)
 for index = 1, count do
  local value = params[index]
  if type(value) == "table" and type(value["$ref"]) == "string" then
   params[index] = assert(instances[value["$ref"]], "Unknown object reference")
  end
 end
 local value = callback(table.unpack(params, 1, count))
 if typeof(value) == "Instance" then return expose(value) end
 return value
end

function LJRPC.Connect(options)
 assert(not socket, "Already connected")
 assert(type(options.Token) == "string" and #options.Token >= 32, "A Lua token is required")
 assert(type(options.Url) == "string" and options.Url:match("^wss://"), "WSS URL required")
 local transport = options.WebSocket or WebSocket
 assert(transport and type(transport.connect) == "function", "WebSocket client unavailable")
 local channel = transport.connect(options.Url)
 socket = channel
 local busy = false
 local function send(message)
  channel:Send(Http:JSONEncode(message))
 end
 channel.OnClose:Connect(function()
  if socket == channel then socket = nil; resetHandles() end
 end)
 channel.OnMessage:Connect(function(raw)
  local decoded, request = pcall(Http.JSONDecode, Http, raw)
  if not decoded or type(request) ~= "table" or request.jsonrpc ~= "2.0" or type(request.id) ~= "string" then return end
  if busy or socket ~= channel then return end
  busy = true
  task.spawn(function()
   local response = {jsonrpc = "2.0", id = request.id}
   local callback = methods[request.method]
   if request.method == "Eval" and options.AllowEval == true then
    callback = function(source, ...)
     assert(type(source) == "string", "Expected Luau source")
     local chunk, reason = loadstring(source, "LJRPC/Eval")
     assert(chunk, reason)
     return chunk(LJRPC, ...)
    end
   end
   if not callback then
    response.error = {code = -32601, message = "Method not found"}
   else
    local ok, value = pcall(invoke, callback, request.params, request.argc)
    if ok then
     response.result = value
    else
     response.error = {code = -32000, message = tostring(value):sub(1, 500)}
    end
   end
   if socket == channel then
    local encoded, payload = pcall(Http.JSONEncode, Http, response)
    if encoded and response.result == nil and not response.error then
     payload = '{"jsonrpc":"2.0","id":'..Http:JSONEncode(request.id)..',"result":null}'
    end
    if not encoded then
     payload = Http:JSONEncode({jsonrpc = "2.0", id = request.id, error = {code = -32603, message = "Result is not JSON serializable"}})
    end
    pcall(function()channel:Send(payload)end)
   end
   busy = false
  end)
 end)
 send({type = "hello", role = "lua", token = options.Token})
 return LJRPC
end

function LJRPC.Close()
 local channel = socket
 socket = nil
 resetHandles()
 if channel then channel:Close() end
end

return LJRPC
