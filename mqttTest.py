#!/usr/bin/python
# -*- coding: utf-8 -*-
import paho.mqtt.client as mqtt

mqttc = mqtt.Client("python_pub")
mqttc.connect("mosquitto", 1883)
mqttc.publish("nodemcu/a0:20:a6:13:1b:be/exec", 'loadFirmware()')
mqttc.loop(2) #timeout = 2s
