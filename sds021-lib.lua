local M = {}

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

M.InputLength = 10

local ID = nil

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

function M.divBy10ToString(n)
	local dec = n % 10
	local round = n - dec
	local int = round / 10
	return int.."."..dec
end

local startIdx = 20
local i = 0

local meanPM25 = 0
local meanPM10 = 0

function M.resetValues()
	meanPM10 = 0
	meanPM25 = 0
	i = 0
end

function M.incrMean(m, n, x)
	return (m * n + x) / (n + 1)
end

function M.handleData(dataBuffer)
	local _PM25 = to16BitsInteger(dataBuffer:byte(4), dataBuffer:byte(3))/10
	local _PM10 = to16BitsInteger(dataBuffer:byte(6), dataBuffer:byte(5))/10
	if (i%5) == 0 then 
		log("Read data: PM2.5=".._PM25.." PM10=".._PM10.." heapFree:"..node.heap())
	end
	i = i + 1
	if i >= startIdx then
		meanPM10 = incrMean(meanPM10, i - startIdx , _PM10)
		meanPM25 = incrMean(meanPM25, i - startIdx , _PM25)
	end
	return _PM25, _PM10, meanPM25, meanPM10
end

function M.readData(buffer)
	
	local start = 0
	local i
	for i=1,#buffer do
		if buffer:byte(i) == MSG_Head then
			start = i
			break;
		end
	end
	if start == 0 then 
		log("No head found "..toHexString(buffer))
		return 
	end
	if #buffer + start - 1 < M.InputLength then 
		log("Buffer too small"..toHexString(buffer))
		return 
	end
	local dataBuffer = buffer:sub(start,start+M.InputLength)
	if not(dataBuffer:byte(M.InputLength) == MSG_Tail) then
		if #buffer - start +1 >= M.InputLength then
			return M.readData(buffer:sub(start+1, #buffer))
		end
		log("No tail found"..toHexString(buffer))
	end
	if not validChecksum(dataBuffer) then
		log("Invalid checksum"..toHexString(buffer))
	end
	-- update id
	ID = to16BitsInteger(buffer:byte(8), buffer:byte(9))
	local command = dataBuffer:byte(2)
	if command==CMD_Data then
		return M.handleData(dataBuffer)
	end
	if command == CMD_Reply then
		log("Reply: "..toHexString(dataBuffer))
		return
	end
	log("Invalid command "..toHexString(buffer))
end


function M.makeMessage(action, set, address)
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

function M.packMessage(msg)
	local ret=""
	local i
	for i=1,#msg do
		ret = ret..string.char(msg[i])
	end
	ret = ret..string.char(checksum(ret, 3, 17))
	ret = ret..string.char(MSG_Tail)
	return ret
end

function M.setAwake(working)
	local msg = M.makeMessage(ACTION_State, true, ID)
	if working then
		msg[5] = 0x01
	end
	uart.write(0,packMessage(msg))
end

return M

