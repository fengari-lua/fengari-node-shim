-- Emulation of https://luarocks.org/modules/hoelzro/lua-term

local js = require "js"
local node_process = js.global.process

local M = {}

M.isatty = function(file)
	if file == io.stdout then
		return node_process.stdout.isTTY
	end
	return false
end

return M
