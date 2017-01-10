-- remote logging


local function url_encode(str)
  if (str) then
    str = string.gsub (str, "\n", "\r\n")
    str = string.gsub (str, "([^%w %-%_%.%~])",
        function (c) return string.format ("%%%02X", string.byte(c)) end)
    str = string.gsub (str, " ", "+")
  end
  return str    
end

local bufferizedLogs = {}

function log(message)
    if( not logReady) then 
        print(message)
        if(#bufferizedLogs > 20) then
            -- save some memory in case the log server is down
            return
        end
        bufferizedLogs[ #bufferizedLogs + 1 ] = message
    end
    httpGet("http://nodemcu-logger/?log="..url_encode(message))
end

function initLogSystem()
    local con = net.createConnection(net.TCP, 0)
    con:dns("nodemcu-logger", function(c, ip)
        if not(ip == nil) then 
            logReady = true
            local _, reset_reason = node.bootreason()
            local msg = "Log system started, bootreason: "..reset_reason
            log(msg)
            for k,v in pairs(bufferizedLogs) do
                log(v)
            end
            bufferizedLogs = nil
        end
    end)
end
