wifi.setmode(wifi.STATION)
wifi.sta.config("SSID", "password")
wifi.sta.connect()

loggerHost = nil
firmwareHost = nil