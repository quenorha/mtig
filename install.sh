#!/bin/bash

wget -q --spider http://google.com

if [ $? -eq 0 ]; then
    echo "Online"
else
    echo "Offline"
fi

echo "Activation IP Forwarding"
/etc/config-tools/config_routing -c general state=enabled

echo "Installation Docker"
opkg install -V3 /media/sd/docker_20.10.5_armhf.ipk

#echo "Modification configuration serveur Web"
#cp /media/sd/mode_http+https.conf /etc/lighttpd/mode_http+https.conf
#/etc/init.d/lighttpd stop
#/etc/init.d/lighttpd start

echo "Arrêt Docker"
/etc/init.d/dockerd stop
sleep 3

echo "Déplacement docker vers la carte SD"
cp -r /home/docker /media/sd
cp /media/sd/daemon.json /etc/docker/daemon.json

echo "Démarrage Docker"
/etc/init.d/dockerd start
sleep 3

#echo "Installation image Grafana"
#docker load < /media/sd/grafana.tar

#echo "Installation image Influxdb"
#docker load < /media/sd/influxdb.tar

echo "Création network"
docker network create wago

echo "Création volumes"
docker volume create v_grafana
docker volume create v_influxdb

echo "Démarrage Mosquitto"
docker run -d -p 1883:1883 -p 9001:9001 --restart=unless-stopped --name c_mosquitto -v $PWD/mosquitto.conf:/mosquitto/config/mosquitto.conf eclipse-mosquitto:2.0.11

echo "Démarrage InfluxDB"
docker run -d -p 8086:8086 --name c_influxdb --net=wago --restart unless-stopped -v v_influxdb influxdb:1.8.6

echo "Démarrage Grafana"
docker run -d -p 3000:3000 --name c_grafana -e GF_PANELS_DISABLE_SANITIZE_HTML=true --net=wago --restart unless-stopped -v v_grafana grafana/grafana:8.0.0

echo "Démarrage Telegraf"
docker run -d --restart=unless-stopped --name=c_telegraf -v $PWD/telegraf.conf:/etc/telegraf/telegraf.conf:ro telegraf:1.19.1
