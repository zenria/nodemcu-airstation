gpiosw = {}

function gpiosw.setup(pin)
    gpio.mode(pin,gpio.INT, gpio.PULLUP)
    local i = 0
    local function coucou(level, ts)
        i = i + 1
        local curI = i
        debounce = tmr.create()
        debounce:alarm(20, tmr.ALARM_SINGLE, function()
            if(i == curI)then
                lvl = gpio.read(pin)
                --print("gpio pin: "..pin.." => "..lvl)
                mqttReporter.sendValue("/gpiosw-"..pin, lvl)
            end
        end)
    end
    gpio.trig(pin, "both", coucou)
end

gpiosw.setup(1)
gpiosw.setup(2)
gpiosw.setup(3)
--gpiosw.setup(4)
gpiosw.setup(5)
gpiosw.setup(6)
gpiosw.setup(7)
--gpiosw.setup(8)
--gpiosw.setup(9)
--gpiosw.setup(10)
