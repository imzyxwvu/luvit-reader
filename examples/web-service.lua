net = require "net"
http_codec = require "http-codec" -- luvi-based Luvit provides decoders to decode HTTP headers
reader = require "reader"

net.createServer(function(client)
	local decode = http_codec.decoder()
	reader.wrap(client, function(reader)
		local header = reader:decode(decode)
		if header then
			if header.path == "/" then
				client:write"HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nIt works!"
			else
				client:write"HTTP/1.1 302 Found\r\nLocation: /\r\nContent-Length: 0\r\n\r\n"
			end
		end
		client:destroy()
	end)
end):listen(8070)
