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

local function boot()
    --compileAndRemoveIfNeeded('mqttReporter.lua') 
    --dofile("mqttReporter.lc")
    require "mqttReporter"
    mqttReporter.connect("mosquitto", function()
        log("Connected to MQTT broker")
    end)

    compileAndRemoveIfNeeded("loadFirmware.lua")
    dofile("loadFirmware.lc")
    compileAndRemoveIfNeeded("http.lua")
    dofile("http.lc")
    compileAndRemoveIfNeeded('log.lua') 
    dofile("log.lc")

    initLogSystem()
    waitIfExcBoot(function()
        if file.exists("app.lua") then
            log("Loading app.lua")
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

