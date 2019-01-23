#!/bin/bash
for file in /etc/openvpn/ccd/*
do
 # do something on $file
   ips=$(cat "$file")
   ips_array=( $ips )
   name_array=(${file//\// })
   echo ${ips_array[1]}, ${ips_array[2]}, ${name_array[3]} >> ./current_ips.tmp
done
cat ./current_ips.tmp | sort -V > ./current_ips.txt
rm ./current_ips.tmp
