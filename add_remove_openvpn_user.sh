#!/bin/bash

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

function usage {
 cat << EOF
 Usage: $0 [OPTIONS] user.name



EOF
}

function main {
    if [  $# -eq 0 ]; then
        usage
    else
        openvpn_home_dir="/etc/openvpn"
        easy_rsa_dir="$openvpn_home_dir/easy-rsa"
        ccd_dir="$openvpn_home_dir/ccd"
        user_name=$1
        find_free_ip
        free_user_ip=$last_ip

        if [ -e "$easy_rsa_dir/keys/$user_name.key" ]; then
            printf "There is a key already made for the user $s" $user_name
            echo ""
            echo "Do you really want to revoke access for this  user?"
            printf "Y/n [ENTER]: "
            read user_answer
            if (( $user_answer == "Y" )) || ((  $user_answer == "y" )); then
                echo "Revoking keys for user $user_name"
                cd "$easy_rsa_dir"
                . ./vars
                ./revoke-full "$user_name"
                rm -f "$easy_rsa_dir/keys/$user_name*"
                rm -f "$ccd_dir/$user_name"
                echo "That's it. The $user_name now doesn't have any key"
            elif (( $user_answer == "N" )) || ((  $user_answer == "n" )); then
                echo "Ok. Thanks for using our tool :)"
                usage
            else
                echo "Sorry. I didn't understend your answer. Could you please try again?"
                usage
            fi

        else
            echo "Generating keys..."
            cd $easy_rsa_dir
            . ./vars
            ./pkitool $user_name

            touch $ccd_dir/$user_name
            echo "ifconfig-push 10.10.10.$free_user_ip 10.10.10.$((free_user_ip-1))" > "$ccd_dir/$user_name"
        fi

    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
