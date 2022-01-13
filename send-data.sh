#!/bin/sh

BROKERS="<-- bootstrap servers -->"
USERNAME="<-- user -->"
PASSWORD="<-- pwd -->"
TOPIC="<-- topic -->"

num=${1-1}

for i in $(seq 1 $num)
do
    echo "Hello $i!" | kafkacat -k "\"$i\"" -b $BROKERS -P -X security.protocol=SASL_SSL -X sasl.mechanisms=PLAIN -X sasl.username=$USERNAME -X sasl.password=$PASSWORD -t $TOPIC &
done
