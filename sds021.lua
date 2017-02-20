local sds021 = require "sds021-lib"

local function sendValues(PM25, PM10)
	if PM10==nil then
		log("SDS021 - Unable to read values / no values received")
		return
	end
	mqttReporter.sendValue("/PM2.5", string.format("%.2f", PM25))
	mqttReporter.sendValue("/PM10", string.format("%.2f", PM10))
    log("Sending PM2.5="..string.format("%.2f", PM25).." PM10="..string.format("%.2f", PM10))
end 

function sds021app()
	-- setup uart
	uart.alt(1)
	uart.setup(0, 9600, 8, uart.PARITY_NONE, uart.STOPBITS_1, 0)
	--uart.on("data", string.char(MSG_Tail), readData, 0)
	local PM10, PM25, meanPM10, meanPM25
    uart.on("data", sds021.InputLength * 2, function()
    	PM25, PM10, meanPM25, meanPM10 = sds021.readData()
    end, 0)
	log("UART set up")

	-- launch loops
	i=0 
	wait(30000, function(timer)			
		log("Sleep")
 		sds021.setAwake(false)
 		sendValues(meanPM25, meanPM10)
 		timer:unregister()
	end)
	wait(240000, function(gTimer)
		log("Wake up")
		sds021.setAwake(true)
		i=0 
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
