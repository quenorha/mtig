#!/bin/bash

wget -q --spider http://google.com

if [ $? -eq 0 ]; then
    echo "Accès Internet détecté, installation Online"
	wget https://github.com/WAGO/docker-ipk/releases/download/v1.0.4-beta/docker_20.10.5_armhf.ipk -P /tmp/
	mkdir /root/config
	wget https://raw.githubusercontent.com/quenorha/mtig/main/conf/mosquitto.conf -P /root/config/
	wget https://raw.githubusercontent.com/quenorha/mtig/main/conf/telegraf.conf -P /root/config/
	wget https://raw.githubusercontent.com/quenorha/mtig/main/conf/daemon.json -P /root/config/
	echo "Installation Docker"
	opkg install -V3 /tmp/docker_20.10.5_armhf.ipk
	
else
    echo "Aucun accès Internet détecté, installation Offline"
	echo "Installation Docker"
	opkg install -V3 /tmp/docker_20.10.5_armhf.ipk
fi

echo "Activation IP Forwarding"
/etc/config-tools/config_routing -c general state=enabled

#echo "Modification configuration serveur Web"
#cp /media/sd/mode_http+https.conf /etc/lighttpd/mode_http+https.conf
#/etc/init.d/lighttpd stop
#/etc/init.d/lighttpd start

echo "Arrêt Docker"
/etc/init.d/dockerd stop
sleep 3

echo "Déplacement docker vers la carte SD"
cp -r /home/docker /media/sd
cp /root/config/daemon.json /etc/docker/daemon.json

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
docker run -d -p 1883:1883 -p 9001:9001 --restart=unless-stopped --name c_mosquitto -v /root/config/mosquitto.conf:/mosquitto/config/mosquitto.conf eclipse-mosquitto:2.0.11

echo "Démarrage InfluxDB"
docker run -d -p 8086:8086 --name c_influxdb --net=wago --restart unless-stopped -v v_influxdb influxdb:1.8.6

echo "Démarrage Grafana"
docker run -d -p 3000:3000 --name c_grafana -e GF_PANELS_DISABLE_SANITIZE_HTML=true --net=wago --restart unless-stopped -v v_grafana grafana/grafana:8.0.0

echo "Démarrage Telegraf"
docker run -d --restart=unless-stopped --name=c_telegraf -v /root/config/telegraf.conf:/etc/telegraf/telegraf.conf:ro telegraf:1.19.1
