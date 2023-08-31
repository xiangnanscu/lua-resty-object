local basearray_setup = require("resty.basearray").setup
local pairs           = pairs
local ipairs          = ipairs
local select          = select
local string          = string
local table           = table
local rawget          = rawget
local type            = type
local setmetatable    = setmetatable
local table_new, nkeys
if ngx then
  table_new = table.new
  nkeys     = require "table.nkeys"
else
  table_new = function(narray, nhash)
    return {}
  end
  nkeys = function(self)
    local n = 0
    for key, _ in pairs(self) do
      n = n + 1
    end
    return n
  end
end

local function object_call(t, ...)
  local self = t:new()
  self:init(...)
  return self
end
local function object_class_tostring(self, ...)
  return string.format('<class %s>', rawget(self, '__name__') or '?')
end
local function object_instance_tostring(self, ...)
  return string.format('<instance %s>', rawget(self.__mro__[1], '__name__') or '?')
end

local object = setmetatable({}, { __call = object_call, __tostring = object_class_tostring })
basearray_setup(object)
object.__call = object_call
object.__tostring = object_instance_tostring
object.__name__ = 'object'
object.__index = object
object.__bases__ = {}
object.__mro__ = { object }

function object.equals(self, o)
  local nt = nkeys(self)
  local no = nkeys(o)
  if nt ~= no then
    return false
  else
    return object.contains(self, o)
  end
end

function object.contains(self, o)
  for k, v in pairs(o) do
    if self[k] ~= v and (type(v) ~= 'table' or type(self[k]) ~= 'table' or not object.equals(v, self[k])) then
      return false
    end
  end
  return true
end

object.__eq = object.equals

function object.new(cls)
  return setmetatable({}, cls)
end

function object.init(self, ...)
  return object.assign(self, ...)
end

function object.assign(self, ...)
  for i = 1, select("#", ...) do
    for k, v in pairs(select(i, ...)) do
      self[k] = v
    end
  end
  return self
end

function object.entries(self)
  local res = setmetatable({}, object)
  for k, v in pairs(self) do
    res[#res + 1] = { k, v }
  end
  return res
end

function object.from_entries(arr)
  local res = setmetatable({}, object)
  for _, e in ipairs(arr) do
    res[e[1]] = e[2]
  end
  return res
end

object.fromEntries = object.from_entries

function object.keys(self)
  local res = setmetatable(table_new(nkeys(self), 0), object)
  for k, _ in pairs(self) do
    res[#res + 1] = k
  end
  return res
end

function object.values(self)
  local res = setmetatable(table_new(nkeys(self), 0), object)
  for _, v in pairs(self) do
    res[#res + 1] = v
  end
  return res
end

function object.copy(self)
  local v_copy = setmetatable({}, object)
  for key, value in pairs(self) do
    if type(value) == 'table' then
      v_copy[key] = object.copy(value)
    else
      v_copy[key] = value
    end
  end
  return v_copy
end

return object
