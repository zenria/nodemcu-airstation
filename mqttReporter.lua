local mqttReporter = {}

local clientId = "nodemcu_"..wifi.sta.getmac()

local rootTopic = "nodemcu/"..wifi.sta.getmac()

local client = nil

local function getTopic(path)
	return rootTopic..path
end

local STATUS_ONLINE = "1"
local STATUS_OFFLINE = "0"

local function sendHeap()
	mqttReporter.sendValue("/heapFree", node.heap())
end



function mqttReporter.connect(host, callback)
	local statusTopic = getTopic("/status")
	client = mqtt.Client(clientId, 120)
	-- will go offline if disconnected
	client:lwt(statusTopic, STATUS_OFFLINE, 0, true)
    print("MQTT - Connecting to "..host)
	client:connect(host, 1883, function(c)
		print("MQTT - Connected")
		-- set online
		c:publish(statusTopic, STATUS_ONLINE, 0, 0)
		-- setup heap reporter
		local timer = tmr.create()
		timer:register(120000, tmr.ALARM_AUTO, sendHeap)
	    timer:start()
	    -- report heap now
	    sendHeap()
		if callback then
			callback()
		end
	end, function(c, error)
        print("Unable to connect to mqtt broker: "..error)
	end)
end

function mqttReporter.sendValue(path, value)
	client:publish(getTopic(path), value, 0, 0)
end

return mqttReporter
