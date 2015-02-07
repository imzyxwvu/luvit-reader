--
--  Coroutine-based Stream Reader for Luvit
--  (c) 2015 zyxwvu Shi <imzyxwvu@icloud.com>
-- 

local reader = { decoders = {} }
local crunning, cyield = coroutine.running, coroutine.yield

function reader.decoders.line(buffer)
	local l, r = buffer:find("\r?\n")
	if l and r then
		if r < #buffer then -- in case there's something left
			return buffer:sub(1, l - 1), buffer:sub(r + 1, -1)
		else return buffer:sub(1, l - 1) end
	end
end

function reader.resume(thread, ...)
	local s, err = coroutine.resume(thread, ...)
	if not s then
		print(debug.traceback(thread, err))
	end
end

local reader_mt = { __index = {} }

function reader_mt.__index:push(str, err)
	if not str then
		self.stopped = true
		if self.decoder then
			reader.resume(self.waiting, nil, err or "over")
		end
	elseif self.buffer then
		self.buffer = self.buffer .. str
		if self.decoder then
			local s, result, rest = pcall(self.decoder, self.buffer)
			if not s then
				reader.resume(self.waiting, nil, result)
			elseif result then
				if rest and #rest > 0 then
					self.buffer = rest
				else
					self.buffer = nil
				end
				reader.resume(self.waiting, result)
			end
		end
	else
		if self.decoder then
			local s, result, rest = pcall(self.decoder, str)
			if not s then
				self.buffer = str
				reader.resume(self.waiting, nil, result)
			elseif result then
				if rest and #rest > 0 then self.buffer = rest end
				reader.resume(self.waiting, result)
			else self.buffer = str end
		else self.buffer = str end
	end
end

function reader_mt.__index:decode(decoder_name)
	assert(not self.decoder, "already reading")
	local decoder = reader.decoders[decoder_name] or decoder_name
	if self.buffer then
		local s, result, rest = pcall(decoder, self.buffer)
		if not s then
			return nil, result
		elseif result then
			if rest and #rest > 0 then
				self.buffer = rest
			else
				self.buffer = nil
			end
			return result
		end
	end
	if self.stopped then return nil, "stopped" end
	self.waiting, self.decoder = crunning(), decoder
	local result, err = cyield()
	self.waiting, self.decoder = nil, nil
	return result, err
end

function reader_mt.__index:read(len)
	local function read_some(buffer)
		if #buffer <= len then return buffer elseif #buffer > len then
			return buffer:sub(1, len), buffer:sub(len + 1, -1)
		end
	end
	local cache = {}
	while len > 0 do
		local block, err = self:decode(read_some)
		if block then
			cache[#cache + 1] = block
			len = len - #block
		else
			cache[#cache + 1] = self.buffer
			self.buffer = tconcat(cache)
			return nil, err
		end
	end
	return tconcat(cache)
end

function reader_mt.__index:peek()
	assert(not self.decoder, "already reading")
	if self.buffer then -- if there has been something cached
		local buffer = self.buffer
		self.buffer = nil
		return self.buffer
	end
	if self.stopped then return nil, "stopped" end
	self.waiting, self.decoder = crunning(), function(buffer)
		return buffer
	end
	local result, err = cyield()
	self.waiting, self.decoder = nil, nil
	return result, err
end

function reader.new()
	return setmetatable({}, reader_mt)
end

function reader.wrap(stream, restore)
	local self = reader.new()
	stream:on('data', function(chunk) self:push(chunk) end)
	stream:on('end', function() self:push(nil) end)
	reader.resume(coroutine.create(restore), self)
	return self
end

reader_mt.__index.new = reader.new
reader_mt.__index.wrap = reader.wrap

return reader