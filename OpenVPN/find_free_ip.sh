#!/bin/bash

function assign_variables {
    openvpn_home_dir="/etc/openvpn"
    easy_rsa_dir="$openvpn_home_dir/easy-rsa"
    ccd_dir="$openvpn_home_dir/ccd"
    user_name=$1
    find_free_ip
    free_user_ip=$last_ip
}

function find_free_ip {
    #tmp_ips_array=()
    declare -a tmp_ips_array

    for file in /etc/openvpn/ccd/*
    do
        ips=$(cat "$file")
        ips_from_file=( $ips )
        name_from_file=(${file//\// })
        echo ${ips_from_file[1]}, ${ips_from_file[2]}, ${name_from_file[3]} >> ./current_ips.tmp
        echo ${ips_from_file[1]} >> ips_array.tmp
    done
    sort -t. -n -k1,1 -k2,2 -k3,3 -k4,4 ./current_ips.tmp > current_ips.txt
    sort -t. -n -k1,1 -k2,2 -k3,3 -k4,4 ./ips_array.tmp > ./ips.txt
    rm ./current_ips.tmp
    rm ./ips_array.tmp

    last_ip=8
    filename="./ips.txt"
    while IFS='' read -r line #|| [[ -n "$line" ]]; do
    do
        octet=( ${line//./ } )
        #echo  ${octet[3]}
        current_addres=${octet[3]}
        last_ip=$(($last_ip+2))
        if [ $last_ip -ne $current_addres ]; then
            rm ./ips.txt
            #return $last_ip
            break
        fi
        done < "$filename"
}

assign_variables
echo $free_user_ip
