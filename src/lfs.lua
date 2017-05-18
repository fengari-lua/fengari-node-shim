-- Emulation of https://keplerproject.github.io/luafilesystem
-- Currently missing: lfs.lock_dir, lfs.unlock_dir, lfs.setmode

local js = require "js"
local node_process = js.global.process
local node_fs = node_process.mainModule:require "fs"

local M = {}

local function getstat(stats, field)
	if field == "mode" then
		if stats:isFile() then
			return "file"
		elseif stats:isDirectory() then
			return "directory"
		elseif stats:isBlockDevice() then
			return "block device"
		elseif stats:isCharacterDevice() then
			return "char device"
		elseif stats:isSymbolicLink() then
			return "link"
		elseif stats:isFIFO() then
			return "named pipe"
		elseif stats:isSocket() then
			return "socket"
		else
			return "other"
		end
	elseif field == "access" then
		return js.tonumber(stats.atime) / 1000
	elseif field == "modification" then
		return js.tonumber(stats.mtime) / 1000
	elseif field == "change" then
		return js.tonumber(stats.ctime) / 1000
	elseif field == "permissions" then
		local mode = stats.mode
		return ((mode & node_fs.constants.S_IRUSR) ~= 0 and "r" or "-")
			.. ((mode & node_fs.constants.S_IWUSR) ~= 0 and "w" or "-")
			.. ((mode & node_fs.constants.S_IXUSR) ~= 0 and "x" or "-")
			.. ((mode & node_fs.constants.S_IRGRP) ~= 0 and "r" or "-")
			.. ((mode & node_fs.constants.S_IWGRP) ~= 0 and "w" or "-")
			.. ((mode & node_fs.constants.S_IXGRP) ~= 0 and "x" or "-")
			.. ((mode & node_fs.constants.S_IROTH) ~= 0 and "r" or "-")
			.. ((mode & node_fs.constants.S_IWOTH) ~= 0 and "w" or "-")
			.. ((mode & node_fs.constants.S_IXOTH) ~= 0 and "x" or "-")
	else
		return math.tointeger(stats[field])
	end
end

local function fillstats(stats, t)
	t.dev = getstat(stats, "dev")
	t.ino = getstat(stats, "ino")
	t.mode = getstat(stats, "mode")
	t.nlink = getstat(stats, "nlink")
	t.uid = getstat(stats, "uid")
	t.gid = getstat(stats, "gid")
	t.rdev = getstat(stats, "rdev")
	t.access = getstat(stats, "access")
	t.modification = getstat(stats, "modification")
	t.change = getstat(stats, "change")
	t.size = getstat(stats, "size")
	t.permissions = getstat(stats, "permissions")
	t.blocks = getstat(stats, "blocks")
	t.blksize = getstat(stats, "blksize")
	return t
end

local function getattributes(field, ...)
	local ok, stats = pcall(...)
	if not ok then
		return nil, stats.message, -stats.errno
	end
	if type(field) == "string" then
		return getstat(stats, field)
	elseif type(field) == "table" then
		return fillstats(stats, field)
	else
		return fillstats(stats, {})
	end
end

M.attributes = function(path, field)
	return getattributes(field, path, node_fs.statSync, node_fs)
end

M.symlinkattributes = function(path, field)
	return getattributes(field, path, node_fs.lstatSync, node_fs)
end

M.chdir = function(path)
	local ok, err = pcall(node_process.chdir, node_process, path)
	if not ok then
		return nil, err.message, -err.errno
	end
	return true
end

M.currentdir = function()
	return node_process:cwd()
end

local function dir_next(self)
	local i = self.i
	if i >= self.list.length then
		return nil
	end
	local v = self.list[i]
	self.i = i + 1
	return v
end
M.dir = function(path)
	local dir_obj = {
		list = node_fs:readdirSync(path);
		i = 0;
		next = dir_next;
		close = function(self)
			self.i = math.huge
			self.list = nil
		end;
	}
	return dir_next, dir_obj
end

M.link = function(old, new, symlink)
	local ok, err
	if symlink then
		ok, err = pcall(node_fs.symlinkSync, node_fs, new, old)
	else
		ok, err = pcall(node_fs.linkSync, node_fs, old, new)
	end
	if not ok then
		return nil, err.message, -err.errno
	end
	return true
end

M.mkdir = function(dirname)
	local ok, err = pcall(node_fs.mkdirSync, node_fs, dirname)
	if not ok then
		return nil, err.message, -err.errno
	end
	return true
end

M.rmdir = function(dirname)
	local ok, err = pcall(node_fs.rmdirSync, node_fs, dirname)
	if not ok then
		return nil, err.message, -err.errno
	end
	return true
end

M.touch = function(filepath, atime, mtime)
	atime = atime or math.huge -- node.js converts this to 'now'
	assert(type(atime) == "number")
	mtime = mtime or atime
	assert(type(mtime) == "number")
	local ok, err = pcall(node_fs.utimesSync, node_fs, filepath, atime, mtime)
	if not ok then
		return nil, err.message, -err.errno
	end
	return true
end

return M
