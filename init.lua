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

function wait(millis, callback)
    local timer = tmr.create()
    timer:register(millis, tmr.ALARM_SEMI, function()
        callback(timer)
    end)
    timer:start()
end


local function boot()
    compileAndRemoveIfNeeded('mqttReporter.lua') 
    dofile("mqttReporter.lc")
    --require "mqttReporter"
    mqttReporter.connect("mosquitto", function()
        log("Connected to MQTT broker")
    end)

    compileAndRemoveIfNeeded("http.lua")
    dofile("http.lc")
    compileAndRemoveIfNeeded('log.lua') 
    dofile("log.lc")

    initLogSystem()
    waitIfExcBoot(function()
        local loadLocal = true
        if not(firmwareHost==nil) then
            local url = "http://"..firmwareHost.."/"..wifi.sta.getmac().."/app.lua"
            print("Try to load firmware from "..url)
            httpGet(url, function(statusCode,response)
                if(statusCode == 200) then
                    loadLocal = false
                    log("Writing app.lua to flash from "..url)
                    file.remove("app.lua")
                    file.remove("app.lc")
                    file.open("app.lua", "w+")
                    file.write(response)
                    file.close()
                    response=nil
                    node.task.post(0,function()
                        compileAndRemoveIfNeeded("app.lua")
                        dofile("app.lc")
                        log("Firmware loaded successfully")
                    end)
                end
            end)
        end

        wait(10000, function()
            if loadLocal and file.exists("app.lua") then
                compileAndRemoveIfNeeded("app.lua")
            end
            if loadLocal and file.exists("app.lc") then
                log("Loading local app")
                dofile("app.lc")
            end
        end)
    end)
end

waitIfExcBoot(function()
    waitForWifi(function()
        print("Connected to wifi, starting")
        waitIfExcBoot(boot)
    end)
end)

