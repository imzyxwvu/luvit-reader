# Decoder-based Stream Reader for Luvit

This library aims to help you take the advantages of Lua coroutines to simplify the code for reading structured data from a stream.

# Decoder

A decoder is a Lua function that accepts the stream buffer and return the expanded structured data plus the rest of buffer. In case of the data we have is not enough, it returns nil. In case of the data is malformed, it throws a Lua error.

This is an example to decode a line:

    function decode_line(buffer)
      local l, r = buffer:find("\r?\n")
      if l and r then
        if r < #buffer then -- in case there's something left
          return buffer:sub(1, l - 1), buffer:sub(r + 1, -1)
        else return buffer:sub(1, l - 1) end
      end
    end
    
# Reader

To use the stream reader, we need to require it first:

    reader_library = require "reader"
    
And create a reader instance:
    
    reader = reader_library.new()

Whenever there is new data got from a stream, we push it into the reader:

    stream:on('data', function(data) reader:push(data) end)
    
And when the stream is over:

    stream:on('end', function() reader:push(nil) end)

When everything of a reader is ready, we need to create a coroutine thread to use it:

    reader_library.resume(coroutine.create(function()
        local line = reader:decode(decode_line)
    end))

Or just use the reader to convert async read into a sync style:

    reader:peek()
