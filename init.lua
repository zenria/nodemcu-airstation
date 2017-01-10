print("Connecting to wifi...")

local compileAndRemoveIfNeeded = function(f)
   if file.open(f) then
      file.close()
      print('Compiling:', f)
      node.compile(f)
      file.remove(f)
      collectgarbage()
   end
end

compileAndRemoveIfNeeded("setupWifi.lua")
dofile("setupWifi.lc")

local function waitForWifi(callback)
    local timer = tmr.create()
    timer:register(500, tmr.ALARM_SEMI, 
    function()
        if wifi.sta.getip()==nil then
            print("Waiting for an IP address!") 
            timer:start()
        else
            timer=nil
            print("Got an IP address: "..wifi.sta.getip())
            collectgarbage()
            callback()
        end             
    end)
    timer:start()
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
    print("Starting http server on port 80")
    if not(httpServer==nil) then
        print("Closing previously lanched server")
        httpServer:close()
    end
    httpServer=net.createServer(net.TCP)
    httpServer:listen(80,function(conn)
        conn:on("receive", function(client,request)
            local _, _, method, path, vars = string.find(request, "([A-Z]+) (.+)?(.+) HTTP");
            if(method == nil)then
                _, _, method, path = string.find(request, "([A-Z]+) (.+) HTTP");
            end
            local _GET = {}
            if (vars ~= nil)then
                for k, v in string.gmatch(vars, "([^&=]+)=([^&]+)&*") do
                    _GET[k] = v
                end
            end

            local msg = "Received HTTP request: "..method.." "..path
            log(msg)

            local response = nil

            if(path == "/load-firmware") then
                -- todo ;)
                response = loadFirmware(_GET)
            else
                if not(appHandler==nil) then
                    response = appHandler(path, _GET)
                else
                    response = createResponse("500 Internal Server Error", "No appHandler global defined", "text/plain")
                end
            end


            client:send(response, function(client)
                    client:close();
                    collectgarbage();
                end);
        end)
    end)
    print("HTTP server started on port 80")
end

local function waitIfExcBoot(fun)
    local _, reset_reason = node.bootreason()
    if(reset_reason == 3)then
        print("Booted on Software Exception, waiting 10s before each boot step")
        local timer = tmr.create()
        timer:register(10000, tmr.ALARM_SEMI, 
            function()
                fun()
            end)
    timer:start()
else
    fun()
end

end

local function boot()
    compileAndRemoveIfNeeded("http.lua")
    dofile("http.lc")
    compileAndRemoveIfNeeded('loadFirmware.lua') 
    dofile("loadFirmware.lc")
    compileAndRemoveIfNeeded('log.lua') 
    dofile("log.lc")
    initLogSystem()
    startServer()
    waitIfExcBoot(function()
        if file.exists("app.lua") then
            dofile("app.lua")
        end
    end)
end

waitIfExcBoot(function()
    waitForWifi(function()
        print("Connected to wifi, starting")
        waitIfExcBoot(boot)
    end)
end)

