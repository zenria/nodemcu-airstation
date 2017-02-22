local sds021 = require "sds021-lib"

local meanPM25=0
local meanPM10=0

local function sendValues(PM25, PM10)
	mqttReporter.sendValue("/PM2.5", string.format("%.2f", PM25))
	mqttReporter.sendValue("/PM10", string.format("%.2f", PM10))
    log("Sending PM2.5="..string.format("%.2f", PM25).." PM10="..string.format("%.2f", PM10))
end 

local i=0
local startIdx=20

local function incrMean(m, n, x)
	return (m * n + x) / (n + 1)
end


local function dataCallback(PM25, PM10)
	if i%5 == 0 then
		log("PM25="..PM25.." PM10="..PM10)
	end
	i = i + 1
	if i >= startIdx then
		if i == startIdx then
			log("Start computing mean")
		end
		meanPM25 = incrMean(meanPM25, i - startIdx, PM25)
		meanPM10 = incrMean(meanPM10, i - startIdx, PM10)
	end
end


function sds021app()
	-- setup uart
	uart.alt(1)
	uart.setup(0, 9600, 8, uart.PARITY_NONE, uart.STOPBITS_1, 0)

	sds021.on("data", dataCallback)
	uart.on("data", string.char(sds021.MSG_Tail), sds021.readData, 0)
    --uart.on("data", sds021.InputLength * 2, sds021.readData, 0)
	log("UART set up")

	-- launch loops
	wait(30000, function(timer)			
		log("Sleep")
 		sds021.setAwake(false)
 		sendValues(meanPM25, meanPM10)
 		timer:unregister()
	end)
	wait(240000, function(gTimer)
		log("Wake up")
		i=0
		sds021.setAwake(true)
		wait(30000, function(wTimer)
	 		sendValues(meanPM25, meanPM10)
			log("Sleep")
			sds021.setAwake(false)
			gTimer:start()
			wTimer:unregister()
			collectgarbage()
		end)
	end)
	log("Launched SDS021 app")
end
sds021app()
