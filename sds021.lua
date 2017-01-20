local MSG_Head = 0xAA
local MSG_Tail = 0xAB
local CMD_Command = 0xB4
local CMD_Data = 0xC0
local CMD_Reply = 0xC5
local ACTION_Mode = 0x2
local ACTION_Query = 0x4
local ACTION_Id = 0x5
local State = 0x6
local Version = 0x7
local Interval = 0x8

local InputLength = 10

local PM25 = nil
local PM10 = nil
local ID = nil

local testBuffer = string.char(0xAA,0xC0,0x73,0x00,0x9E,0x00,0xA9,0xEA,0xA4,0xAB)
local testBuffer2 = string.char(0xAA,0xC0,0x86,0x00,0x09,0x01,0xA9,0xEA,0x23,0xAB)

if log == nil then
	log = print
end 

local function to16BitsInteger(h,l)
	return (h << 8) + l
end

local function checksum(buffer, start_idx, end_idx)
	local chk = 0
	local i
	for i = start_idx, end_idx do
		chk = chk + buffer:byte(i);
	end
	return chk & 0xFF
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
	int = string.format("%.0f", int)
	return int.."."..dec
end

local function handleData(dataBuffer)
	PM25 = divBy10ToString(to16BitsInteger(dataBuffer:byte(4), dataBuffer:byte(3)))
	PM10 = divBy10ToString(to16BitsInteger(dataBuffer:byte(6), dataBuffer:byte(5)))
	log("Read data: PM2.5="..PM25.." PM10="..PM10)
end

local function readData(buffer)
	log("Parsing "..toHexString(buffer))
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
	if dataBuffer:byte(2)==CMD_Data then
		handleData(dataBuffer)
		return
	end
	log("TODO: handle reply")
end



local function makeMessage(action, set, address)

	local ret = string.char(
		MSG_Head, -- 0
		CMD_Command, -- 1
		action, -- 2
		set, -- 3
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
		address >> 8, -- 15
		address & 0xFF -- 16
		)
	ret = ret..checksum(ret, 3, 17)
	ret = ret..MSG_Tail
	return ret
end

readData(testBuffer)
readData(testBuffer2)

--print("chk: "..string.format("%02X", checksum(testBuffer,2,8)))
--print("chk: "..string.format("%02X", checksum(testBuffer2,3,8)))

print(string.format("%04X", ID))
