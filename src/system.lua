-- Emulation of https://github.com/o-lim/luasystem

local js = require "js"
local node_process = js.global.process
local node_child_process = node_process.mainModule:require "child_process"

local M = {}

M.gettime = function()
	local t = node_process:hrtime()
	return t[0] + t[1]*1e-9
end

local zero_time = node_process:hrtime()
M.monotime = function()
	local t = node_process:hrtime(zero_time)
	return t[0] + t[1]*1e-9
end

M.sleep = function(n)
	assert(type(n) == "number")
	node_child_process:execSync(string.format("sleep %f", n))
end

return M
