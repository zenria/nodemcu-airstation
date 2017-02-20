if log == nil then
	log = print
end 

if bit == nil then
	-- not un eLua env, emulate bit module
	bit = require "bit"
end

if node == nil then 
	node = {}
	node.heap = function()return 100 end
end
