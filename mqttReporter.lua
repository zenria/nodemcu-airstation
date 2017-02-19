mqttReporter = {}

local clientId = "nodemcu_"..wifi.sta.getmac()

local rootTopic = "nodemcu/"..wifi.sta.getmac()

local client = nil

print("MQTT - root topic: "..rootTopic)

local function getTopic(path)
	return rootTopic..path
end

local STATUS_ONLINE = "1"
local STATUS_OFFLINE = "0"

local function sendHeap()
	mqttReporter.sendValue("/heapFree", node.heap())
end

local reconnect = nil

function mqttReporter.connect(host, callback)
	local statusTopic = getTopic("/status")
    local rpcTopic = getTopic("/exec")
    reconnect = function(c2)

        if log == nil then log = print end
    
		client = mqtt.Client(clientId, 120)
		-- will go offline if disconnected
		client:lwt(statusTopic, STATUS_OFFLINE, 0, true)

	    client:on("message", function(client, topic, data) 
	        if topic == rpcTopic then
	            node.input(data)
	        end
	    end)
	    
	    log("MQTT - Connecting to "..host)
		client:connect(host, 1883, function(c)
			log("MQTT - Connected")
			-- set online
			c:publish(statusTopic, STATUS_ONLINE, 0, 0)
	        -- subscribe to rcp topic
	        c:subscribe(rpcTopic, 2)
			-- setup heap reporter
			local timer = tmr.create()
			timer:register(120000, tmr.ALARM_AUTO, sendHeap)
		    timer:start()
		    -- report heap now
		    sendHeap()
			if c2 then
				c2()
			end
		end, function(c, error)
	        log("Unable to connect to mqtt broker: "..error)
		end)
	end
	reconnect(callback)
end

function mqttReporter.sendValue(path, value)
	local function pub()
		return client:publish(getTopic(path), value, 0, 0)
	end
	if not pub() then
        log("Unable to send to MQTT "..path.." "..value..", try to reconnect")
		reconnect(function()
			if not pub() then
				log("Unable to send to MQTT "..path.." "..value)
            end
		end)
	end
end

--return mqttReporter
