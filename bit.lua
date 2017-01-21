-- required function of the bit module, usable in moderne lua having bitwise operators available
local bit = {}
bit.lshift = function(a,b) return a << b end
bit.rshift = function(a,b) return a >> b end
bit.band = function(a,b) return a & b end
return bit
