local dhtTemperature = nil
local dhtHumidity = nil
local dhtPin = 5

function readDht()    
    status,temp,humi,temp_decimal,humi_decimal = dht.read(dhtPin)
    if( status == dht.OK ) then
        dhtTemperature = temp.."."..temp_decimal
        dhtHumidity = humi.."."..humi_decimal
    elseif( status == dht.ERROR_CHECKSUM ) then
        log( "nodemcu-airstation - dht Checksum error." );
    elseif( status == dht.ERROR_TIMEOUT ) then
        log( "nodemcu-airstation - dht Time out." );
    end
    return temp,humi
end

function appHandler(path, params)
    local response = nil
    if(path == "/")then
        jsonValue = {
            temperature = dhtTemperature,
            humidity = dhtHumidity
        }
        json = cjson.encode(jsonValue)
        if(json)then
            response = createResponse(200, json, "application/json")
        else
            response = createResponse(500, "Cannot encode json", "text/plain")
        end
    else
        response = createResponse("404 NOT FOUND", "Not found", "text/plain")
    end
    return response
end

local function logStatus()
    log("dhtTemperature:"..dhtTemperature)
    log("dhtHumidity:"..dhtHumidity)
    log("heapFree:"..node.heap())
end

local function app() 
    readDht()
    local timer = tmr.create()
    local n = 1
    timer:register(5000, tmr.ALARM_SEMI, function()
        readDht()
        timer:start()
        n = n + 1
        if n % 12 == 0 then
            logStatus()
        end
    end)
    timer:start()
end

app()
