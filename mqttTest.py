#!/usr/bin/python
# -*- coding: utf-8 -*-
import paho.mqtt.client as mqtt

mqttc = mqtt.Client("python_pub")
mqttc.connect("mosquitto", 1883)
mqttc.publish("sensor1/temp", "15")
mqttc.publish("sensor1/hum", "68")
mqttc.publish("sensor2/values", "{\"temp\": \"13\", \"hum\": \"70\"}")
mqttc.publish("nodemcu/02:BA:BB:BC:BD/values", "{\"temp\": \"13\", \"hum\": \"70\"}")
mqttc.loop(2) #timeout = 2s
