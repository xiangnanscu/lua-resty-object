local array = require("resty.array")
local pairs        = pairs
local ipairs       = ipairs
local select       = select
local string       = string
local table        = table
local rawget       = rawget
local type         = type
local setmetatable = setmetatable
local table_concat = table.concat
local table_remove = table.remove
local table_insert = table.insert
local table_sort   = table.sort
local error        = error
local table_new, table_clear, nkeys, clone
if ngx then
  table_clear = table.clear
  table_new   = table.new
  nkeys       = require "table.nkeys"
  clone       = require("table.clone")
else
  table_new = function(narray, nhash)
    return {}
  end
  table_clear = function(self)
    for key, _ in pairs(self) do
      self[key] = nil
    end
  end
  nkeys = function(self)
    local n = 0
    for key, _ in pairs(self) do
      n = n + 1
    end
    return n
  end
  clone = function(self)
    local copy = {}
    for key, value in pairs(self) do
      copy[key] = value
    end
    return copy
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
local function resolve_index(self, index, is_end, no_max)
  if index == nil then
    return is_end and #self or 1
  elseif index == 0 then
    return 1
  elseif index < 0 then
    if #self + index >= 0 then
      return #self + index + 1
    else
      return 1
    end
    -- index >= 1
  elseif index > #self then
    if not no_max then
      return #self == 0 and 1 or #self
    else
      return index
    end
  else
    return index
  end
end

local object = setmetatable({}, { __call = object_call, __tostring = object_class_tostring })
object.__call = object_call
object.__tostring = object_instance_tostring
object.__name__ = 'object'
object.__index = object
object.__bases__ = {}
object.__mro__ = { object }

function object.__eq(self, o)
  return object.equals(self, o)
end

-- {1,2} + {2,3} = {1,2,2,3}
function object.__add(self, o)
  return object.concat(self, o)
end

-- {1,2} - {2,3} = {1}
function object.__sub(self, o)
  local res = setmetatable({}, object)
  local od = o:as_set()
  for i = 1, #self do
    if not od[self[i]] then
      res[#res + 1] = self[i]
    end
  end
  return res
end

function object.new(cls)
  return setmetatable({}, cls)
end

function object.init(self, attrs)
  for key, value in pairs(attrs or {}) do
    self[key] = value
  end
  return self
end

function object.assign(self, ...)
  local n = select("#", ...)
  for i = 1, n do
    for k, v in pairs(select(i, ...)) do
      self[k] = v
    end
  end
  return self
end

function object.entries(self)
  local res = object()
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

function object.contains(self, o)
  for k, v in pairs(o) do
    if self[k] ~= v and (type(v) ~= 'table' or type(self[k]) ~= 'table' or not object.equals(v, self[k])) then
      return false
    end
  end
  return true
end

function object.equals(self, o)
  local nt = nkeys(self)
  local no = nkeys(o)
  if nt ~= no then
    return false
  else
    return object.contains(self, o)
  end
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

function object.flat(self, depth)
  -- [0, 1, 2, [3, 4]] => [0, 1, 2, 3, 4]
  if depth == nil then
    depth = 1
  end
  if depth > 0 then
    local n = #self
    local res = setmetatable(table_new(n, 0), object)
    for i = 1, #self do
      local v = self[i]
      if type(v) == "table" then
        local vt = object.flat(v, depth - 1)
        for j = 1, #vt do
          res[#res + 1] = vt[j]
        end
      else
        res[#res + 1] = v
      end
    end
    return res
  else
    return setmetatable(clone(self), object)
  end
end

function object.flat_map(self, callback)
  -- equivalent to self:map(callback):flat(1), more efficient
  local n = #self
  local res = setmetatable(table_new(n, 0), object)
  for i = 1, n do
    local v = callback(self[i], i, self)
    if type(v) == "table" then
      for j = 1, #v do
        res[#res + 1] = v[j]
      end
    else
      res[#res + 1] = v
    end
  end
  return res
end

object.flatMap = object.flat_map

function object.concat(...)
  local n = 0
  local m = select("#", ...)
  for i = 1, m do
    n = n + #select(i, ...)
  end
  local res = setmetatable(table_new(n, 0), object)
  n = 0
  for i = 1, m do
    local e = select(i, ...)
    for j = 1, #e do
      res[n + j] = e[j]
    end
    n = n + #e
  end
  return res
end

function object.every(self, callback)
  for i = 1, #self do
    if not callback(self[i], i, self) then
      return false
    end
  end
  return true
end

function object.fill(self, v, s, e)
  s = resolve_index(self, s)
  e = resolve_index(self, e, true, true)
  for i = s, e do
    self[i] = v
  end
  return self
end

function object.filter(self, callback)
  local res = setmetatable({}, object)
  for i = 1, #self do
    if callback(self[i], i, self) then
      res[#res + 1] = self[i]
    end
  end
  return res
end

function object.find(self, callback)
  if type(callback) == 'function' then
    for i = 1, #self do
      if callback(self[i], i, self) then
        return self[i]
      end
    end
  else
    for i = 1, #self do
      if self[i] == callback then
        return self[i]
      end
    end
  end
end

function object.find_index(self, callback)
  for i = 1, #self do
    if callback(self[i], i, self) then
      return i
    end
  end
  return -1
end

object.findIndex = object.find_index

function object.for_each(self, callback)
  for i = 1, #self do
    callback(self[i], i, self)
  end
end

object.forEach = object.for_each

function object.group_by(self, callback)
  local res = {}
  for i = 1, #self do
    local key = callback(self[i], i, self)
    if not res[key] then
      res[key] = setmetatable({}, object)
    end
    res[key][#res[key] + 1] = self[i]
  end
  return res
end

function object.includes(self, value, s)
  -- Array{'a', 'b', 'c'}:includes('c', 3)    // true
  -- Array{'a', 'b', 'c'}:includes('c', 100)  // false
  s = resolve_index(self, s, false, true)
  for i = s, #self do
    if self[i] == value then
      return true
    end
  end
  return false
end

function object.index_of(self, value, s)
  s = resolve_index(self, s, false, true)
  for i = s, #self do
    if self[i] == value then
      return i
    end
  end
  return -1
end

object.indexOf = object.index_of

function object.join(self, sep)
  return table_concat(self, sep)
end

function object.last_index_of(self, value, s)
  s = resolve_index(self, s, false, true)
  for i = s, 1, -1 do
    if self[i] == value then
      return i
    end
  end
  return -1
end

object.lastIndexOf = object.last_index_of

function object.map(self, callback)
  local n = #self
  local res = setmetatable(table_new(n, 0), object)
  for i = 1, n do
    res[i] = callback(self[i], i, self)
  end
  return res
end

function object.pop(self)
  return table_remove(self)
end

function object.push(self, ...)
  local n = #self
  for i = 1, select("#", ...) do
    self[n + i] = select(i, ...)
  end
  return #self
end

function object.reduce(self, callback, init)
  local i = 1
  if init == nil then
    init = self[1]
    i = 2
  end
  if init == nil and #self == 0 then
    error("Reduce of empty Array with no initial value")
  end
  for j = i, #self do
    init = callback(init, self[j], j, self)
  end
  return init
end

function object.reduce_right(self, callback, init)
  local i = #self
  if init == nil then
    init = self[i]
    i = i - 1
  end
  if init == nil and #self == 0 then
    error("Reduce of empty Array with no initial value")
  end
  for j = i, 1, -1 do
    init = callback(init, self[j], j, self)
  end
  return init
end

object.reduceRright = object.reduce_right

function object.reverse(self)
  local n = #self
  local e = n % 2 == 0 and n / 2 or (n - 1) / 2
  for i = 1, e do
    self[i], self[n + 1 - i] = self[n + 1 - i], self[i]
  end
  return self
end

function object.shift(self)
  return table_remove(self, 1)
end

function object.slice(self, s, e)
  local res = setmetatable({}, object)
  s = resolve_index(self, s)
  e = resolve_index(self, e, true)
  for i = s, e do
    res[#res + 1] = self[i]
  end
  return res
end

function object.some(self, callback)
  for i = 1, #self do
    if callback(self[i], i, self) then
      return true
    end
  end
  return false
end

function object.sort(self, callback)
  table_sort(self, callback)
  return self
end

function object.splice(self, s, del_cnt, ...)
  local n = #self
  s = resolve_index(self, s)
  if del_cnt == nil or del_cnt >= n - s + 1 then
    del_cnt = n - s + 1
  elseif del_cnt <= 0 then
    del_cnt = 0
  end
  local removed = setmetatable({}, object)
  for i = s, del_cnt + s - 1 do
    table_insert(removed, table_remove(self, s))
  end
  for i = select("#", ...), 1, -1 do
    local e = select(i, ...)
    table_insert(self, s, e)
  end
  return removed
end

function object.unshift(self, ...)
  local n = select("#", ...)
  for i = n, 1, -1 do
    local e = select(i, ...)
    table_insert(self, 1, e)
  end
  return #self
end

-- other methods

function object.group_by_key(self, key)
  local res = {}
  for i = 1, #self do
    local k = self[i][key]
    if not res[k] then
      res[k] = setmetatable({}, object)
    end
    res[k][#res[k] + 1] = self[i]
  end
  return res
end

function object.map_key(self, key)
  local n = #self
  local res = setmetatable(table_new(n, 0), object)
  for i = 1, n do
    res[i] = self[i][key]
  end
  return res
end

object.sub = object.slice

function object.clear(self)
  return table_clear(self)
end

function object.dup(self)
  local already = {}
  for i = 1, #self do
    local e = self[i]
    if already[e] then
      return e
    else
      already[e] = true
    end
  end
end

object.duplicate = object.dup

local FIRST_DUP_ADDED = {}
function object.dups(self)
  local already = {}
  local res = setmetatable({}, object)
  for i = 1, #self do
    local e = self[i]
    local a = already[e]
    if a ~= nil then
      if a ~= FIRST_DUP_ADDED then
        res[#res + 1] = a
        already[e] = FIRST_DUP_ADDED
      end
      res[#res + 1] = e
    else
      already[e] = e
    end
  end
  return res
end

function object.dup_map(self, callback)
  local already = {}
  for i = 1, #self do
    local e = self[i]
    local k = callback(e, i, self)
    if already[k] then
      return e
    else
      already[k] = true
    end
  end
end

function object.dups_map(self, callback)
  local already = {}
  local res = setmetatable({}, object)
  for i = 1, #self do
    local e = self[i]
    local k = callback(e, i, self)
    local a = already[k]
    if a ~= nil then
      if a ~= FIRST_DUP_ADDED then
        res[#res + 1] = a
        already[k] = FIRST_DUP_ADDED
      end
      res[#res + 1] = e
    else
      already[k] = e
    end
  end
  return res
end

function object.uniq(self)
  local already = {}
  local res = setmetatable({}, object)
  for i = 1, #self do
    local key = self[i]
    if not already[key] then
      res[#res + 1] = key
      already[key] = true
    end
  end
  return res
end

function object.uniq_map(self, callback)
  local already = {}
  local res = setmetatable({}, object)
  for i = 1, #self do
    local key = callback(self[i], i, self)
    if not already[key] then
      res[#res + 1] = self[i]
      already[key] = true
    end
  end
  return res
end

function object.as_set(self)
  local res = setmetatable(table_new(0, #self), object)
  for i = 1, #self do
    res[self[i]] = true
  end
  return res
end

function object.exclude(self, callback)
  local res = setmetatable({}, object)
  for i = 1, #self do
    if not callback(self[i], i, self) then
      res[#res + 1] = self[i]
    end
  end
  return res
end

function object.count(self, callback)
  local res = 0
  for i = 1, #self do
    if callback(self[i], i, self) then
      res = res + 1
    end
  end
  return res
end

function object.count_exclude(self, callback)
  local res = 0
  for i = 1, #self do
    if not callback(self[i], i, self) then
      res = res + 1
    end
  end
  return res
end

function object.combine(self, n)
  if #self == n then
    return object { self }
  elseif n == 1 then
    return object.map(self, function(e)
      return object { e }
    end)
  elseif #self > n then
    local head = self[1]
    local rest = object.slice(self, 2)
    return object.concat(object.combine(rest, n), object.combine(rest, n - 1):map(function(e)
      return object { head, unpack(e) }
    end))
  else
    return object {}
  end
end

return object