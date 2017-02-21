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
M.MSG_Tail = MSG_Tail
M.E_CHECKSUM = 1
M.E_NOTAIL = 2
M.E_NOHEAD = 3
M.E_BUFTOOSMALL = 4
M.E_INVALIDCMD = 5
M.ERROR_MSG = {}
M.ERROR_MSG[M.E_CHECKSUM] = "Invalid checksum"
M.ERROR_MSG[M.E_NOTAIL] = "No tail"
M.ERROR_MSG[M.E_NOHEAD] = "No head"
M.ERROR_MSG[M.E_BUFTOOSMALL] = "Buffer too small"
M.ERROR_MSG[M.E_INVALIDCMD] = "Invalid command"


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

local onDataReadCallback = function(PM25, PM10)
	log("Read data: PM2.5=".._PM25.." PM10=".._PM10.." heapFree:"..node.heap())
end

local onReplyCallback = function(buffer)
	log("Reply: "..toHexString(buffer))
end

local onErrorCallback = function(errorCode, buffer)
	log("Error "..M.ERROR_MSG[errorCode].." -- "..toHexString(buffer))	
end

local uartWrite = nil;
if uart then
	uartWrite = uart.write
end


function M.on(name, callback)
	if name == "data" then
		onDataReadCallback = callback
	elseif name == "reply" then
		onReplyCallback = callback
	elseif name == "error" then
		onErrorCallback = callback
	elseif name == "uartwrite" then
		uartWrite = callback;
	end
end


function M.divBy10ToString(n)
	local dec = n % 10
	local round = n - dec
	local int = round / 10
	return int.."."..dec
end


local incompleteBuffer = nil

function M.resetInternalBuffer()
	incompleteBuffer = nil
end

function M.readData(buffer, partialBuffer)
	if incompleteBuffer and not partialBuffer then
		buffer = incompleteBuffer..buffer
	end
	local start = 0
	local i
	for i=1,#buffer do
		if buffer:byte(i) == MSG_Head then
			start = i
			break;
		end
	end
	if start == 0 then 
		onErrorCallback(M.E_NOHEAD, buffer)
		return 
	end
	if #buffer + start - 1 < M.InputLength then 
		--onErrorCallback(M.E_BUFTOOSMALL, buffer)
		incompleteBuffer = buffer
		return 
	end
	local dataBuffer = buffer:sub(start,start+M.InputLength)
	if not(dataBuffer:byte(M.InputLength) == MSG_Tail) then
		if #buffer - start + 1 >= M.InputLength then
			M.readData(buffer:sub(start+1, #buffer), true)
		end
		incompleteBuffer = buffer
		-- onErrorCallback(M.E_NOTAIL, buffer)
		return
	end
	-- we may have found complete frame, let reset the buffer to the end of this frame
	if #buffer - start + 1 >  M.InputLength then
		incompleteBuffer = buffer:sub(start+1, #buffer)
	else
		incompleteBuffer = nil
	end
	if not validChecksum(dataBuffer) then
		onErrorCallback(M.E_CHECKSUM, buffer)
		return
	end
	-- update id
	ID = to16BitsInteger(buffer:byte(8), buffer:byte(9))
	local command = dataBuffer:byte(2)
	if command==CMD_Data then
		local _PM25 = to16BitsInteger(dataBuffer:byte(4), dataBuffer:byte(3))/10
		local _PM10 = to16BitsInteger(dataBuffer:byte(6), dataBuffer:byte(5))/10
		onDataReadCallback(_PM25, _PM10)
	elseif command == CMD_Reply then
		onReplyCallback(dataBuffer)
	else
		onErrorCallback(M.E_INVALIDCMD, dataBuffer)
	end
	if incompleteBuffer then 
		M.readData("")
	end
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
	uartWrite(0,M.packMessage(msg))
end

return M

