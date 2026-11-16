local Http = game:GetService("HttpService")
local Encoding = game:GetService("EncodingService")
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
local destroyConnections = {}
local destroyed = setmetatable({}, {__mode = "k"})

function LJRPC.ConnectionGuard()
 local connection = socket
 return function() return socket == connection end
end

local function release(id)
 local instance = instances[id]
 if not instance then return false end
 local connection = destroyConnections[id]
 if connection then connection:Disconnect() end
 destroyConnections[id] = nil
 instances[id], handles[instance] = nil, nil
 handleCount -= 1
 return true
end

LJRPC.Register("Release", release)

function LJRPC.DestroyInstance(instance)
 local descendants = instance:GetDescendants()
 instance:Destroy()
 destroyed[instance] = true
 release(handles[instance])
 for _, child in ipairs(descendants) do
  destroyed[child] = true
  release(handles[child])
 end
end

local function resetHandles()
 for _, connection in pairs(destroyConnections) do connection:Disconnect() end
 table.clear(destroyConnections)
 table.clear(instances)
 table.clear(handles)
 handleCount = 0
end

local function expose(instance)
 if destroyed[instance] then return nil end
 local id = handles[instance]
 if not id then
  assert(handleCount < 512, "Object reference limit reached")
  id = Http:GenerateGUID(false)
  handles[instance], instances[id] = id, instance
  handleCount += 1
  if typeof(instance) == "Instance" then
   destroyConnections[id] = instance.Destroying:Connect(function()
    destroyed[instance] = true
    release(id)
   end)
  end
 end
 return { ["$ref"] = id }
end

local function decode(value, depth)
 if type(value) ~= "table" then return value end
 assert(depth < 24, "Arguments nested too deeply")
 if type(value["$ref"]) == "string" then
  return (assert(instances[value["$ref"]], "Unknown object reference"))
 end
 local kind = value["$type"]
 if kind == "buffer" then return Encoding:Base64Decode(buffer.fromstring(value.data)) end
 if kind == "Content" then
  if value.source == "None" then return Content.none end
  if value.source == "Uri" then return Content.fromUri(value.uri) end
  if value.source == "Object" then return Content.fromObject((decode(value.object, depth + 1))) end
  error("Unsupported Roblox Content source", 0)
 end
 if kind == "Vector3" then return Vector3.new(value.x, value.y, value.z) end
 if kind == "Vector2" then return Vector2.new(value.x, value.y) end
 if kind == "Color3" then return Color3.new(value.r, value.g, value.b) end
 if kind == "CFrame" then return CFrame.new(table.unpack(value.components)) end
 if kind == "EnumItem" then return Enum[value.enum][value.name] end
 if kind == "UDim" then return UDim.new(value.scale,value.offset) end
 if kind == "UDim2" then return UDim2.new(decode(value.x,depth+1),decode(value.y,depth+1)) end
 if kind == "NumberRange" then return NumberRange.new(value.min,value.max) end
 if kind == "Rect" then return Rect.new(decode(value.min,depth+1),decode(value.max,depth+1)) end
 if kind == "Ray" then return Ray.new(decode(value.origin,depth+1),decode(value.direction,depth+1)) end
 if kind == "BrickColor" then return BrickColor.new(value.number) end
 if kind == "PhysicalProperties" then return PhysicalProperties.new(value.density,value.friction,value.elasticity,value.frictionWeight,value.elasticityWeight) end
 if kind == "NumberSequenceKeypoint" then return NumberSequenceKeypoint.new(value.time, value.value, value.envelope) end
 if kind == "ColorSequenceKeypoint" then return ColorSequenceKeypoint.new(value.time, decode(value.value, depth+1)) end
 if kind == "NumberSequence" then return NumberSequence.new(decode(value.keypoints, depth+1)) end
 if kind == "ColorSequence" then return ColorSequence.new(decode(value.keypoints, depth+1)) end
 if kind == "Font" then return Font.new(value.family, decode(value.weight, depth+1), decode(value.style, depth+1)) end
 if kind == "DateTime" then return DateTime.fromUnixTimestampMillis(value.unixTimestampMillis) end
 if kind == "TweenInfo" then return TweenInfo.new(value.time, decode(value.easingStyle, depth+1), decode(value.easingDirection, depth+1), value.repeatCount, value.reverses, value.delayTime) end
 for key, item in pairs(value) do value[key] = decode(item, depth + 1) end
 return value
end

local function encode(value, depth)
 local kind = typeof(value)
 if kind == "Instance" or kind == "Object" then return expose(value) end
 if kind == "buffer" then
  return {["$type"]=kind, data=buffer.tostring(Encoding:Base64Encode(value))}
 end
 if kind == "Content" then
  return {["$type"]=kind, source=value.SourceType.Name, uri=value.Uri, object=encode(value.Object, depth + 1)}
 end
 if kind == "Vector3" then return {["$type"] = kind, x = value.X, y = value.Y, z = value.Z} end
 if kind == "Vector2" then return {["$type"] = kind, x = value.X, y = value.Y} end
 if kind == "Color3" then return {["$type"] = kind, r = value.R, g = value.G, b = value.B} end
 if kind == "CFrame" then return {["$type"] = kind, components = {value:GetComponents()}} end
 if kind == "EnumItem" then return {["$type"] = kind, enum = (tostring(value.EnumType):gsub("^Enum%.", "")), name = value.Name} end
 if kind == "UDim" then return {["$type"]=kind, scale=value.Scale, offset=value.Offset} end
 if kind == "UDim2" then return {["$type"]=kind, x=encode(value.X,depth+1), y=encode(value.Y,depth+1)} end
 if kind == "NumberRange" then return {["$type"]=kind, min=value.Min, max=value.Max} end
 if kind == "Rect" then return {["$type"]=kind, min=encode(value.Min,depth+1), max=encode(value.Max,depth+1)} end
 if kind == "Ray" then return {["$type"]=kind, origin=encode(value.Origin,depth+1), direction=encode(value.Direction,depth+1)} end
 if kind == "BrickColor" then return {["$type"]=kind, number=value.Number} end
 if kind == "PhysicalProperties" then return {["$type"]=kind, density=value.Density, friction=value.Friction, elasticity=value.Elasticity, frictionWeight=value.FrictionWeight, elasticityWeight=value.ElasticityWeight} end
 if kind == "NumberSequenceKeypoint" then return {["$type"]=kind, time=value.Time, value=value.Value, envelope=value.Envelope} end
 if kind == "ColorSequenceKeypoint" then return {["$type"]=kind, time=value.Time, value=encode(value.Value, depth+1)} end
 if kind == "NumberSequence" then return {["$type"]=kind, keypoints=encode(value.Keypoints, depth+1)} end
 if kind == "ColorSequence" then return {["$type"]=kind, keypoints=encode(value.Keypoints, depth+1)} end
 if kind == "Font" then return {["$type"]=kind, family=value.Family, weight=encode(value.Weight, depth+1), style=encode(value.Style, depth+1)} end
 if kind == "DateTime" then return {["$type"]=kind, unixTimestampMillis=value.UnixTimestampMillis} end
 if kind == "TweenInfo" then return {["$type"]=kind, time=value.Time, easingStyle=encode(value.EasingStyle, depth+1), easingDirection=encode(value.EasingDirection, depth+1), repeatCount=value.RepeatCount, reverses=value.Reverses, delayTime=value.DelayTime} end
 if kind == "RaycastResult" then return {["$type"]=kind, instance=encode(value.Instance, depth+1), position=encode(value.Position, depth+1), normal=encode(value.Normal, depth+1), material=encode(value.Material, depth+1), distance=value.Distance} end
 if kind == "table" then
  assert(depth < 24, "Result nested too deeply or cyclic")
  local result = {}
  for key, item in pairs(value) do result[key] = encode(item, depth + 1) end
  return result
 end
 return value
end

local function invoke(callback, params, count)
 for index = 1, count do params[index] = decode(params[index], 0) end
 return encode(callback(table.unpack(params, 1, count)), 0)
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
