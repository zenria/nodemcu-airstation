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

local startIdx = 20
local i = 0

local meanPM25 = 0
local meanPM10 = 0

local function incrMean(m, n, x)
	return (m * n + x) / (n + 1)
end

local function handleData(dataBuffer)
	_PM25 = to16BitsInteger(dataBuffer:byte(4), dataBuffer:byte(3))/10
	_PM10 = to16BitsInteger(dataBuffer:byte(6), dataBuffer:byte(5))/10
	if (i%5) == 0 then 
		log("Read data: PM2.5= ".._PM25.." PM10= ".._PM10.."heapFree:"..node.heap())
	end
	i = i + 1
	if i >= startIdx then
		meanPM10 = incrMean(meanPM10, i - startIdx , _PM10)
		meanPM25 = incrMean(meanPM25, i - startIdx , _PM25)
	end
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


local function sendMessage(msg)
    --log("Want to send. "..toHexString(packMessage(msg)))
    uart.write(0,packMessage(msg))
end

local function makeSetAwakeMessage(working)
	local ret = makeMessage(ACTION_State, true, ID)
	if working then
		ret[5] = 0x01
	end
	return ret
end

function setAwake(working)
	sendMessage(makeSetAwakeMessage(working))
end


local function commandOK()
	return createResponse(200, "Command OK", "text/plain")
end

local function sendValues()
	mqttReporter.sendValue("/PM2.5", string.format("%.2f", PM25))
	mqttReporter.sendValue("/PM10", string.format("%.2f", PM10))
    log("Sending PM2.5="..string.format("%.2f", PM25).." PM10="..string.format("%.2f", PM10))
end 

function runMode()
	i=0 
	wait(30000, function()			
		log("Sleep")
 		setAwake(false)
 		PM25 = meanPM25
 		PM10 = meanPM10
 		sendValues()
	end)
	wait(240000, function(gTimer)
		log("Wake up")
		setAwake(true)
		i=0 
		wait(30000, function()
	 		PM25 = meanPM25
	 		PM10 = meanPM10
	 		sendValues()
			log("Sleep")
			setAwake(false)
			gTimer:start()
			collectgarbage()
		end)
	end)
end

function app()
    setupSerial()
	runMode()
end
app()
