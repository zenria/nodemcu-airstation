local alt=164 -- altitude of the measurement place

bme280.init(2, 3)

local function readAndSendData()
    local T, P, H, QNH = bme280.read(alt)
    local temperature, pressure, seaLevelPressure

    if T == nil or P == nil or QNH == nil then
        log("BMP280 - error cannot read data")
        return
    end
    
    if T<0 then
      temperature=string.format("-%d.%02d", -T/100, -T%100)
    else
      temperature=string.format("%d.%02d", T/100, T%100)
    end
    pressure = string.format("%d.%03d", P/1000, P%1000)
    seaLevelPressure = string.format("%d.%03d", QNH/1000, QNH%1000)

    log("BMP280 - temperature="..temperature)
    log("BMP280 - pressure="..pressure)
    log("BMP280 - seaLevelPressure="..seaLevelPressure)

    mqttReporter.sendValue("/bmp280.temperature", temperature)
    mqttReporter.sendValue("/bmp280.pressure", pressure)
    mqttReporter.sendValue("/bmp280.seaLevelPressure", seaLevelPressure)
    
end

wait(2000, function(timer)
    readAndSendData()
    timer:unregister()
end)

local timer = tmr.create()
timer:register(60000, tmr.ALARM_AUTO, readAndSendData)
timer:start()

log("BMP280 - application loaded")

