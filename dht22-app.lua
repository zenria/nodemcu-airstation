local dhtTemperature = nil
local dhtHumidity = nil
local dhtPin = 5

local function readDht()    
    status,temp,humi,temp_decimal,humi_decimal = dht.read(dhtPin)
    if( status == dht.OK ) then
        dhtTemperature = temp
        dhtHumidity = humi
    elseif( status == dht.ERROR_CHECKSUM ) then
        log( "nodemcu-airstation - dht Checksum error." );
    elseif( status == dht.ERROR_TIMEOUT ) then
        log( "nodemcu-airstation - dht Time out." );
    end
    return temp,humi
end


local function logStatus()
    if not(dhtTemperature==nil) then
        log("dhtTemperature:"..dhtTemperature)
        log("dhtHumidity:"..dhtHumidity)
    end
    log("heapFree:"..node.heap())
end

local function dht22app() 
    local n = 1
    wait(10000, function(timer)
        readDht()
        mqttReporter.sendValue("/temperature", dhtTemperature)
        mqttReporter.sendValue("/humidity", dhtHumidity)    
        n = n + 1
        if n % 12 == 0 then
            logStatus()
        end
        timer:start()
    end)
    log("Loaded DHT22 APP")
end
if automaticLaunchApp == nil or automaticLaunchApp then
    dht22app()
end
