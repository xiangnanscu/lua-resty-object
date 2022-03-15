# lua-resty-object
lua object inspired by javascript object
# Synopsis
```lua
local object = require("resty.object")
assert(object{a=1,b=2,c=3}:keys():as_set() == array{'a','b','c'}:as_set())
assert(object{a=1,b=2,c=3}:values():as_set() == array{1,2,3}:as_set())
assert(object{a=1,b=2} == object{a=1,b=2})
assert(object{a=1,b={c=3,d=4}} == object{a=1,b={c=3,d=4}})
assert(object{a=1,b={c=3,d=4}} ~= object{a=1,b={c=3,d=5}})
assert(object{a=1}:assign({b=2}, {c=3}) == object{a=1,b=2,c=3})
assert(object.from_entries(object{a=1,b=2}:entries():map(function(e) return {'k'..e[1], 100 + e[2]} end)) == object{ka=101,kb=102})
```
# api
## object.assign(t, ...)
## object.keys()
## object.values()
## object.entries()
## object.from_entries(t)
## object.equals(t, o)
deeply compare if `t` equals `o`.
## object.contains(t, o)
deeply compare if `t` contains `o`.
