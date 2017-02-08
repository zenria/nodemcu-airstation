function loadFirmware(url)
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
        log("Firmware loaded successfully")
    end)
end
