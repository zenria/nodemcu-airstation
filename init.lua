initVersion = "1.0"

print("Connecting to wifi...")

compileAndRemoveIfNeeded = function(f)
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
if file.exists("app-list.lua") then
    compileAndRemoveIfNeeded("app-list.lua")    
end
if file.exists("app-list.lc") then
    dofile("app-list.lc")
end

local function waitForWifi(callback)
    print("Waiting for an IP address!") 
    local timer = tmr.create()
    timer:register(500, tmr.ALARM_SEMI, 
    function()
        if wifi.sta.getip()==nil then
            timer:start()
        else
            timer:unregister()
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

local loadLocal = true

local function boot()
    compileAndRemoveIfNeeded('mqttReporter.lua') 
    compileAndRemoveIfNeeded("http.lua")
    compileAndRemoveIfNeeded('log.lua') 

    if apps == nil then
        apps = {"app"}
    end

    for k,v in pairs(apps) do
        local fileName = v..".lua"
        if file.exists(fileName) then
            compileAndRemoveIfNeeded(fileName)
        end
    end

    dofile("mqttReporter.lc")
    --require "mqttReporter"
    mqttReporter.connect("mosquitto", function()
        log("Connected to MQTT broker")
    end)
    dofile("http.lc")
    dofile("log.lc")
    initLogSystem()

    waitIfExcBoot(function()
        wait(10000, function()
            if loadLocal  then
                for k,v in pairs(apps) do
                    local fileName = v..".lc"
                    if file.exists(fileName) then
                        log("Loading "..fileName)
                        dofile(fileName)
                    else
                        log("App not found - "..v)
                    end
                end
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

function loadFirmware(fileToLoad)
    if(fileToLoad==nil)then
        fileToLoad = "app"
    end
    if not(firmwareHost==nil) then
        local url = "http://"..firmwareHost.."/"..wifi.sta.getmac().."/"..fileToLoad..".lua"
        log("Try to load firmware from "..url)
        httpGet(url, function(statusCode,response)
            if(statusCode == 200) then
                loadLocal = false
                log("Writing "..fileToLoad..".lua to flash from "..url)
                file.remove(fileToLoad..".lua")
                file.remove(fileToLoad..".lc")
                file.open(fileToLoad..".lua", "w+")
                file.write(response)
                file.close()
                node.restart()
                --response=nil
                --node.task.post(0,function()
                --    compileAndRemoveIfNeeded("app.lua")
                --    dofile("app.lc")
                --    log("Firmware loaded successfully")
                --end)
            end
        end)
    end
end
