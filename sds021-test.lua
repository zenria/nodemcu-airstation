require "mockups"
sds021 = require "sds021-lib"


local testData1 = string.char(0xAA,0xC0,0x73,0x00,0x9E,0x00,0xA9,0xEA,0xA4,0xAB)
local testData2 = string.char(0xAA,0xC0,0x64,0x00,0x6A,0x00,0xAB,0xA6,0x1F,0xAB)

local function assertEquals(message, v, t)
	if(v==t) then
--		print(message.." - OK ")
		return
	end
	if v == nil then v = "nil" end
	if t == nil then t ="nil" end
	print(message.." - FAIL expected:"..v.." got:"..t)
	die()
end
local function toHexString(buffer)
	local i
	local str = ""
	for i=1,#buffer do
		str = str..string.format("%02X ", buffer:byte(i))
	end
	return str
end	

local function doTest(testData, _PM25, _PM10)
	local PM25,PM10,error
	sds021.on("data", function(__PM25, __PM10)
		PM25 = __PM25
		PM10 = __PM10
		print("PM25="..PM25)
		print("PM10="..PM10)
	end)
	sds021.readData(testData)
	assertEquals("PM25", _PM25, PM25)
	assertEquals("PM10", _PM10, PM10)
end

print("----------- OPTIMAL data")
doTest(testData1, 11.5, 15.8)
doTest(testData2, 10.0, 10.6)
print("----------- DOUBLE data (aligned)")
doTest(string.char(
	0xAA,0xC0,0x64,0x00,0x6A,0x00,0xAB,0xA6,0x1F,0xAB,
	0xAA,0xC0,0x64,0x00,0x6A,0x00,0xAB,0xA6,0x1F,0xAB)
	, 10.0, 10.6, 0, 0)
sds021.resetInternalBuffer()

print("----------- DOUBLE data (wrapped)")
doTest(string.char(
	0xC0,0x64,0x00,0x6A,0x00,0xAB,0xA6,0x1F,0xAB,
	0xAA,0xC0,0x64,0x00,0x6A,0x00,0xAB,0xA6,0x1F,0xAB, 0xAA)
	, 10.0, 10.6, 0, 0)
sds021.resetInternalBuffer()

print("----------- CORRUPT HEAD ")
doTest(string.char(
	0xAA,0xAA,0x00,0x6A,0x00,0xAB,0xA6,0x1F,0xAB,
	0xAA,0xC0,0x64,0x00,0x6A,0x00,0xAB,0xA6,0x1F,0xAB, 0xAA)
	, 10.0, 10.6, 0, 0)
sds021.resetInternalBuffer()
print("----------- CORRUPT HEAD (endswith tail)")
doTest(string.char(
	0xAA,0xAA,0x00,0x6A,0x00,0xAB,0xA6,0x1F,0xAB,
	0xAA,0xC0,0x64,0x00,0x6A,0x00,0xAB,0xA6,0x1F,0xAB)
	, 10.0, 10.6, 0, 0)

sds021.resetInternalBuffer()
print("----------- CORRUPT DATA ")
doTest("", nil, nil, nil, nil)
doTest(string.char(0xAA), nil, nil, nil, nil)
doTest(string.char(0xAB), nil, nil, nil, nil)
doTest(string.char(0xAA, 0xAA), nil, nil, nil, nil)
doTest(string.char(0xAA, 0xAB), nil, nil, nil, nil)
doTest(string.char(0xAB, 0xAB), nil, nil, nil, nil)
doTest(string.char(0xAA,1,2,4,5,6,7,8,10,0xAB), nil, nil, nil, nil)


print("----------- Set awake ")
sds021.on("uartwrite", function(id, buffer)
	print("UART WRITE: "..toHexString(buffer))
end)
sds021.setAwake(true)
sds021.setAwake(false)

sds021.resetInternalBuffer()
print("----------- Test Internal Buffer")
print("--- basic buffer")
doTest(string.char(0xAA), nil, nil)
doTest(string.char(0xC0), nil, nil)
doTest(string.char(0x64), nil, nil)
doTest(string.char(0x00), nil, nil)
doTest(string.char(0x6A), nil, nil)
doTest(string.char(0x00), nil, nil)
doTest(string.char(0xAB), nil, nil)
doTest(string.char(0xA6), nil, nil)
doTest(string.char(0x1F), nil, nil)
doTest(string.char(0xAB), 10.0, 10.6)

print("--- basic buffer again")
doTest(string.char(0xAA), nil, nil)
doTest(string.char(0xC0), nil, nil)
doTest(string.char(0x73), nil, nil)
doTest(string.char(0x00), nil, nil)
doTest(string.char(0x9E), nil, nil)
doTest(string.char(0x00), nil, nil)
doTest(string.char(0xA9), nil, nil)
doTest(string.char(0xEA), nil, nil)
doTest(string.char(0xA4), nil, nil)
doTest(string.char(0xAB), 11.5, 15.8)

sds021.resetInternalBuffer()
print("--- double aligned")
doTest(string.char(
	0xAA,0xC0,0x73,0x00,0x9E,0x00,0xA9,0xEA,0xA4,0xAB,
	0xAA,0xC0,0x64,0x00,0x6A,0x00,0xAB,0xA6,0x1F,0xAB)
	, 10.0, 10.6)
sds021.resetInternalBuffer()

print("--- double aligned (reverse")
doTest(string.char(
	0xAA,0xC0,0x64,0x00,0x6A,0x00,0xAB,0xA6,0x1F,0xAB,
	0xAA,0xC0,0x73,0x00,0x9E,0x00,0xA9,0xEA,0xA4,0xAB)
	, 11.5, 15.8)

print("-- chain on something else")
doTest(testData2, 10.0, 10.6)

