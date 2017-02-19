alt=164 -- altitude of the measurement place

bme280.init(2, 3)

T, P, H, QNH = bme280.read(alt)
if T<0 then
  print(string.format("T=-%d.%02d", -T/100, -T%100))
else
  print(string.format("T=%d.%02d", T/100, T%100))
end
print(string.format("QFE=%d.%03d", P/1000, P%1000))
print(string.format("QNH=%d.%03d", QNH/1000, QNH%1000))
--print(string.format("humidity=%d.%03d%%", H/1000, H%1000))
--D = bme280.dewpoint(H, T)
--if D<0 then
--  print(string.format("dew_point=-%d.%02d", -D/100, -D%100))
--else
--  print(string.format("dew_point=%d.%02d", D/100, D%100))
--end

-- altimeter function - calculate altitude based on current sea level pressure (QNH) and measure pressure
--P = bme280.baro()
--curAlt = bme280.altitude(P, QNH)
--if curAlt<0 then
--  print(string.format("altitude=-%d.%02d", -curAlt/100, -curAlt%100))
--else
--  print(string.format("altitude=%d.%02d", curAlt/100, curAlt%100))
--end
