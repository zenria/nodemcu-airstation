print("nodemcu-airstation - connecting to wifi...")
wifi.setmode(wifi.STATION)
wifi.sta.config("SSID", "password")
wifi.sta.connect()

function waitForWifi(appFunction)
    local timer = tmr.create()
    timer:register(1000, tmr.ALARM_SEMI, 
    function()
        if wifi.sta.getip()==nil then
            print("nodemcu-airstation - waiting for an IP address!") 
            timer:start()
        else
            print("nodemcu-airstation - got an IP address: "..wifi.sta.getip()) 
            appFunction()
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

local appFiles = {
   'app.lua',
}

for i, f in ipairs(appFiles) do compileAndRemoveIfNeeded(f) end

waitForWifi(function()
    print("nodemcu-airstation - connected to wifi, starting")
    dofile("app.lc")
end)
