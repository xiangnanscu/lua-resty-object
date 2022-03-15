local array = require("resty.array")
local pairs = pairs
local ipairs = ipairs
local select = select
local nkeys
if ngx then
  nkeys = require "table.nkeys"
else
  nkeys = function(t)
    local n = 0
    for _, _ in pairs(t) do
      n = n + 1
    end
    return n
  end
end

local object = setmetatable({}, {
  __call = function(t, attrs)
    return setmetatable(attrs or {}, t)
  end
})
object.__index = object
function object.new(cls, t)
  return setmetatable(t or {}, cls)
end
function object.assign(t, ...)
  local n = select("#", ...)
  for i = 1, n do
    for k, v in pairs(select(i, ...)) do
      t[k] = v
    end
  end
  return t
end
function object.entries(t)
  local res = array:new()
  for k, v in pairs(t) do
    res[#res + 1] = {k, v}
  end
  return res
end
function object.from_entries(arr)
  local res = object:new()
  for _, e in ipairs(arr) do
    res[e[1]] = e[2]
  end
  return res
end
object.fromEntries = object.from_entries

function object.keys(t)
  local res = array:new()
  for k, _ in pairs(t) do
    res[#res + 1] = k
  end
  return res
end

function object.values(t)
  local res = array:new()
  for _, v in pairs(t) do
    res[#res + 1] = v
  end
  return res
end

function object.contains(t, o)
  for k, v in pairs(o) do
    if t[k] ~= v and (type(v) ~= 'table' or type(t[k]) ~= 'table' or not object.equals(v, t[k])) then
      return false
    end
  end
  return true
end

function object.__eq(t, o)
  local nt = nkeys(t)
  local no = nkeys(o)
  if nt ~= no then
    return false
  else
    return object.contains(t, o)
  end
end
object.equals = object.__eq

if select('#', ...) == 0 then
  assert(object {a = 1, b = 2, c = 3}:keys():as_set() == array {'a', 'b', 'c'}:as_set())
  assert(object {a = 1, b = 2, c = 3}:values():as_set() == array {1, 2, 3}:as_set())
  assert(object {a = 1, b = 2} == object {a = 1, b = 2})
  assert(object {a = 1, b = {c = 3, d = 4}} == object {a = 1, b = {c = 3, d = 4}})
  assert(object {a = 1, b = {c = 3, d = 4}} ~= object {a = 1, b = {c = 3, d = 5}})
  assert(object {a = 1}:assign({b = 2}, {c = 3}) == object {a = 1, b = 2, c = 3})
  assert(object.from_entries(object {a = 1, b = 2}:entries():map(function(e)
    return {'k' .. e[1], 100 + e[2]}
  end)) == object {ka = 101, kb = 102})
  print("all tests passed!")
end

return object
