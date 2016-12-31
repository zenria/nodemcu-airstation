dhtTemperature = nil
dhtHumidity = nil
dhtPin = 4

function readDht()    
    status,temp,humi,temp_decimal,humi_decimal = dht.read(dhtPin)
    if( status == dht.OK ) then
        dhtTemperature = temp.."."..temp_decimal
        dhtHumidity = humi.."."..humi_decimal
        print("nodemcu-airstation - dht temperature: "..dhtTemperature.." ".."humidity: "..dhtHumidity.."%")
    elseif( status == dht.ERROR_CHECKSUM ) then
        print( "nodemcu-airstation - dht Checksum error." );
    elseif( status == dht.ERROR_TIMEOUT ) then
        print( "nodemcu-airstation - dht Time out." );
    end
    return temp,humi
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


function startServer()
    print("nodemcu-airstation - starting http server on port 80")
    srv=net.createServer(net.TCP)
    srv:listen(80,function(conn)
        conn:on("receive", function(client,request)
            local buf = "";
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

            local response = nil;

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

            client:send(response, function(client)
                    client:close();
                    collectgarbage();
                end);
        end)
    end)
    print("nodemcu-airstation - http server started on port 80")
end

function app() 
    readDht()
    local timer = tmr.create()
    timer:register(5000, tmr.ALARM_SEMI, function()
      readDht()
      timer:start()
    end)
    timer:start()

    startServer()

end

app()
