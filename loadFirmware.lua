function loadFirmware(_GET)
    local url = _GET["url"]
    if url then
        log("Loading app.lua from "..url)
        httpGet(url, function(status_code,response)
            if not(status_code==200)then
                log("Error, cannot load firmware, status_code: "..status_code)
                return
            end
            log("Writing app.lua to flash...")
            file.remove("app.lua")
            file.open("app.lua", "w+")
            file.write(response)
            file.close()
            dofile("app.lua")
            log("Firmware loaded  successfully")
        end)
        return createResponse("200 OK", "url: "..url, "text/plain")
    else
        return createResponse("400 Bad Request", "Bad Request", "text/plain")
    end
    
end