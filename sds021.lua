local MSG_Head = 0xAA
local MSG_Tail = 0xAB
local CMD_Command = 0xB4
local CMD_Data = 0xC0
local CMD_Reply = 0xC5
local ACTION_Mode = 0x2
local ACTION_Query = 0x4
local ACTION_Id = 0x5
local ACTION_State = 0x6
local Version = 0x7
local ACTION_Interval = 0x8

local InputLength = 10

local PM25 = nil
local PM10 = nil
local _PM25 = nil
local _PM10 = nil
local ID = nil


if log == nil then
	log = print
end 

if bit == nil then
	-- not un eLua env, emulate bit module
	bit = require "bit"
end

local function to16BitsInteger(h,l)
	return bit.lshift(h, 8) + l
end

local function checksum(buffer, start_idx, end_idx)
	local chk = 0
	local i
	for i = start_idx, end_idx do
		chk = chk + buffer:byte(i);
	end
	return bit.band(chk, 0xFF)
end

local function validChecksum(buffer)
	return checksum(buffer, 3, 8) == buffer:byte(9)
end

local function toHexString(buffer)
	local i
	local str = ""
	for i=1,#buffer do
		str = str..string.format("%02X ", buffer:byte(i))
	end
	return str
end	

local function divBy10ToString(n)
	local dec = n % 10
	local round = n - dec
	local int = round / 10
	if not(math==nil) then
		int = math.floor(int)
	end
	return int.."."..dec
end

local function handleData(dataBuffer)
	_PM25 = divBy10ToString(to16BitsInteger(dataBuffer:byte(4), dataBuffer:byte(3)))
	_PM10 = divBy10ToString(to16BitsInteger(dataBuffer:byte(6), dataBuffer:byte(5)))
	log("Read data: PM2.5= ".._PM25.." PM10= ".._PM10..)
end

local function handleReply(dataBuffer)
	log("Reply: "..toHexString(dataBuffer))
end	

local function readData(buffer)
	
	local start = 0
	local i
	for i=1,#buffer do
		if buffer:byte(i) == MSG_Head then
			start = i
			break;
		end
	end
	if start == 0 then 
		log("No head found")
		return 
	end
	if #buffer + start - 1 > InputLength then 
		log("Buffer too small")
		return 
	end
	local dataBuffer = buffer:sub(start,start+InputLength)
	if not(dataBuffer:byte(InputLength) == MSG_Tail) then
		log("No tail found")
	end
	if not validChecksum(dataBuffer) then
		log("Invalid checksum")
	end
	-- update id
	ID = to16BitsInteger(buffer:byte(8), buffer:byte(9))
	local command = dataBuffer:byte(2)
	if command==CMD_Data then
		handleData(dataBuffer)
		return
	end
	if command == CMD_Reply then
		handleReply(dataBuffer)
		return
	end
	log("Invalid command "..toHexString(buffer))
end

local function wait(millis, callback)
	local timer = tmr.create()
	timer:register(millis, tmr.ALARM_SEMI, function()
		callback(timer)
	end)
	timer:start()
end


function setupSerial()
	uart.alt(1)
	uart.setup(0, 9600, 8, uart.PARITY_NONE, uart.STOPBITS_1, 0)
	uart.on("data", string.char(MSG_Tail), readData, 0)
	log("UART set up")
end

local function makeMessage(action, set, address)
	address = 0xFFFF
	local setInt = 0x00
	if set then
		setInt = 0x01
	end
	local ret = {
			MSG_Head, -- 0
			CMD_Command, -- 1
			action, -- 2
			setInt , -- 3
			0, -- 4
			0, -- 5
			0, -- 6
			0, -- 7
			0, -- 8
			0, -- 9
			0, -- 10
			0, -- 11
			0, -- 12
			0, -- 13
			0, -- 14
			bit.rshift(address, 8), -- 15
			bit.band(address, 0xFF) -- 16
			}
	return ret
end

local function packMessage(msg)
	local ret=""
	local i
	for i=1,#msg do
		ret = ret..string.char(msg[i])
	end
	ret = ret..string.char(checksum(ret, 3, 17))
	ret = ret..string.char(MSG_Tail)
	return ret
end

local function makeSetIdMessage(newId)
	local ret = makeMessage(ACTION_Id, true, ID)
	ret[14] = bit.rshift(newId, 8)
	ret[15] = bit.band(newId, 0xFF)
	return ret
end


local function makeSetPassiveModeMessage(passive)
	local ret = makeMessage(ACTION_Mode, true, ID)
	if passive then
		ret[5] = 0x01
	end
	return ret
end

local function makeSetAwakeMessage(working)
	local ret = makeMessage(ACTION_State, true, ID)
	if working then
		ret[5] = 0x01
	end
	return ret
end

local function makeSetIntervalMessage(minutes)
	if(minutes > 30) then
		minutes = 30
	end
	local ret = makeMessage(ACTION_Interval, true, ID)
	ret[5] = minutes;
	return ret;
end

local function sendMessage(msg)
    --log("Want to send. "..toHexString(packMessage(msg)))
    uart.write(0,packMessage(msg))
end


local function makeQueryMessage()
	local ret = makeMessage(ACTION_Query, false, ID)
	return ret;
end

function setId(newId)
	sendMessage(makeSetIdMessage(newId))
end

function setPassiveMode(passive)
	sendMessage(makeSetPassiveModeMessage(passive))
end

function setAwake(working)
	sendMessage(makeSetAwakeMessage(working))
end

function setInterval(interval)
	sendMessage(makeSetIntervalMessage(interval))
end

function query()
	sendMessage(makeQueryMessage())
end

local function commandOK()
	return createResponse(200, "Command OK", "text/plain")
end


function appHandler(path, params)
    local response = nil
    if (path == "/" and PM25 == nil) then
        response = createResponse("503 NOT AVAILABLE", "SDS021 not booted", "text/plain")
    elseif(path == "/")then
        jsonValue = {
            PM25 = PM25,
            PM10 = PM10
        }
        json = cjson.encode(jsonValue)
        if(json)then
            response = createResponse(200, json, "application/json")
        else
            response = createResponse(500, "Cannot encode json", "text/plain")
        end
    elseif(path == "/reboot") then
        node.reboot()
    else
        response = createResponse("404 NOT FOUND", "Not found", "text/plain")
    end
    return response
end


function runMode()
	wait(500, function()setPassiveMode(false)end)
	wait(10000, function()			
		log("Sleep")
 		setAwake(false)
 		PM25 = _PM25
 		PM10 = _PM10
	end)
	wait(120000, function(gTimer)
		log("Wake up")
		setAwake(true)
		wait(30000, function()
	 		PM25 = _PM25
	 		PM10 = _PM10
			log("Sleep")
			setAwake(false)
			gTimer:start()
			collectgarbage()
			log("heapFree:"..node.heap())
		end)
	end)
end

function app()
    setupSerial()
	runMode()
end
app()
