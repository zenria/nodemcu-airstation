print("nodemcu-airstation - connecting to wifi...")
wifi.setmode(wifi.STATION)
wifi.sta.config("SSID", "password")
wifi.sta.connect()


local function waitForWifi(callback)
    local timer = tmr.create()
    timer:register(2000, tmr.ALARM_SEMI, 
    function()
        if wifi.sta.getip()==nil then
            print("nodemcu-airstation - waiting for an IP address!") 
            timer:start()
        else
            timer=nil
            print("nodemcu-airstation - got an IP address: "..wifi.sta.getip())
            collectgarbage()
            callback()
        end             
    end)
    timer:start()
end

local compileAndRemoveIfNeeded = function(f)
   if file.open(f) then
      file.close()
      print('nodemcu-airstation - compiling:', f)
      node.compile(f)
      file.remove(f)
      collectgarbage()
   end
end

function createResponse(status, payload, contentType)
    local buf = "HTTP/1.0 "..status.."\r\n"
    buf = buf.."Server: nodemcu-airstation\r\n"
    buf = buf.."Content-Type: "..contentType.."\r\n"
    local contentLength = string.len(payload)
    buf = buf.."Content-Length: "..contentLength.."\r\n"
    buf = buf.."\r\n"
    buf = buf..payload
    return buf;
end

local function startServer()
    print("nodemcu-airstation - starting http server on port 80")
    local srv=net.createServer(net.TCP)
    srv:listen(80,function(conn)
        conn:on("receive", function(client,request)
            local _, _, method, path, vars = string.find(request, "([A-Z]+) (.+)?(.+) HTTP");
            if(method == nil)then
                _, _, method, path = string.find(request, "([A-Z]+) (.+) HTTP");
            end
            local _GET = {}
            if (vars ~= nil)then
                for k, v in string.gmatch(vars, "(%w+)=(%w+)&*") do
                    _GET[k] = v
                end
            end

            print("nodemcu-airstation - received HTTP request: ")
            print("nodemcu-airstation - method: "..method)
            print("nodemcu-airstation - path: "..path)

            local response = nil

            if(path == "/load-firmware")
                -- todo ;)
            else
                response = appHandler(path, _GET)
            end


            client:send(response, function(client)
                    client:close();
                    collectgarbage();
                end);
        end)
    end)
    print("nodemcu-airstation - http server started on port 80")
end

waitForWifi(function()
    print("nodemcu-airstation - connected to wifi, starting")
--    compileAndRemoveIfNeeded('log.lua') 

    dofile("log.lua")
    initLogSystem()

--    startServer()

--    compileAndRemoveIfNeeded('app.lua') 
--    dofile("app.lc")
end)
