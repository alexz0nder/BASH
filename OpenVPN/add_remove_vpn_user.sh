#!/bin/bash

function assign_variables {
    user_email=$1
    echo "user email is $user_email"
    user_name=$(cut -d'@' -f1 <<< "$user_email")
    user_domain=$(cut -d'@' -f2 <<< "$user_email")
    openvpn_home_dir="/etc/openvpn"
    easy_rsa_dir="$openvpn_home_dir/easy-rsa"
    ccd_dir="$openvpn_home_dir/ccd"
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

function generate_new_cert {
    printf "There is a key already made for the user $s" $user_name
    echo ""
    end_date_of_certificate=$(openssl x509 -noout -dates -in "$easy_rsa_dir/keys/$user_name.crt" | grep notAfter | awk -F'=' '{print $NF}' | awk '{printf "%s%s%s", $2, $1, $4}')
    cert_unix_date=$(date -d $end_date_of_certificate +%s)
    today_unix_date=$(date +%s)
    days_to_the_end=$(($cert_unix_date-$today_unix_date))
    days_to_the_end=$(($days_to_the_end/86400))

    echo $cert_unix_date $today_unix_date $days_to_the_end 
    if [[ $days_to_the_end -le 0 ]]; then
        # the case when the user already has a generated key but it is already expired
        #
        echo "And it's is already expired"
        printf "Would you like to renew it? "
        read user_answer
        if [[ $user_answer == "Y" ]] || [[  $user_answer == "y" ]]; then
            cd "$easy_rsa_dir"
            . ./vars
            echo "\nRevoking expired keys for user $user_name"
            #./revoke-full "$user_name"
            #rm -f "$easy_rsa_dir/keys/$user_name*"

            echo "\nGenerating new certificates..."
            #./pkitool $user_name

            echo "That's it. The $user_name now has new certificates."
            end_date_of_certificate=$(openssl x509 -noout -dates -in "$easy_rsa_dir/keys/$user_name.crt" | grep notAfter | awk -F'=' '{print $NF}' | awk '{printf "%s%s%s", $2, $1, $4}')
            cert_unix_date=$(date -d $end_date_of_certificate +%s)
            days_to_the_end=$(($cert_unix_date-$today_unix_date))
            days_to_the_end=$(($days_to_the_end/86400))
            echo "and now it's days to the end is $days_to_the_end"

        elif [[ $user_answer == "N" ]] || [[  $user_answer == "n" ]]; then
            echo "Ok. Thanks for using our tool :)"
            echo "But, yser's certificate still expired and he still can't use VPN"
            echo ""
        else
            echo "Sorry. I didn't understand your answer. Could you please try again?"
            echo ""
            usage
        fi
    else
        # the case when the user already has certificates and they aren't expired yet
        #
        echo "Do you really want to revoke access for this user?"
        printf "Y/n [ENTER]: "
        read user_answer
        if [[ $user_answer == "Y" ]] || [[  $user_answer == "y" ]]; then
            echo "Revoking keys for user $user_name"
            cd "$easy_rsa_dir"
            . ./vars
            #./revoke-full "$user_name"
            #rm -f "$easy_rsa_dir/keys/$user_name*"
            #rm -f "$ccd_dir/$user_name"
            echo "That's it. The $user_name now doesn't have any certificate"
        elif [[ $user_answer == "N" ]] || [[  $user_answer == "n" ]]; then
            echo "Ok. Thanks for using our tool :)"
            echo ""
            usage
        else
            echo "Sorry. I didn't understand your answer. Could you please try again?"
            echo ""
            usage
        fi
    fi
}


function main {
    if [ $# -eq 0 ]; then
        usage
    else
        echo "Firstly we are going to split your email to name and domain and here what we have found:"
        assign_variables $@
        echo "name=${user_name} AT domain=${user_domain}"
        if [ -e "${easy_rsa_dir}/keys/${user_name}.crt" ] && [ -e "${ccd_dir}/${user_name}" ]; then
            echo "there are already generated certificates and ccd file, so it might be you wanted to revoke certs for the user and clean all ends ? :)"
            read -p "If you agree to revoke certs of the ${user_name} user and remove : " YesNo
            if [ $YesNo == "YES" ] then
                ## Remove IPtables rule
                user_ip_adress=$(cat /etc/openvpn/ccd/alexander.baklanov | cut -d' ' -f2)
                iptables_string=$(iptables -L --line-numbers | grep $user_ip_adress)
                iptables_line_number=$(echo "$iptables_string" | cut -d' ' -f1)
                echo "Okay."
                echo "Removing iptables line #$iptables_line_number:"
                echo $iptables_string
                read -p "Are you sure? (Yes/No): " YesNo
                if [ $YesNo == "Yes" ] then
                    iptables -D FORWARD $iptables_line_number
                    echo "iptables rule was succesfully deleted"
                fi

                ## Delete CCD file
                #
                echo "Now I am going to remove the user's CCD file"
                read -p "Are you sure? (Yes/No): " YesNo
                if [ $YesNo == "Yes" ] then
                    rm -f ${ccd_dir}/${user_name}
                    echo "the CCD file was succesfully deleted"
                fi

                ## Revoke certs
                #
                echo "Revoking keys..."
                read -p "Are you sure? (Yes/No): " YesNo
                if [ $YesNo == "Yes" ] then
                    cd ${easy_rsa_dir}
                    . ./vars
                    ./revoke-full 
                fi
            fi

        else
            echo "So. There is neither already generated certificate nor ccd configured file for the user."
            echo "Searching for free IP..."
            find_free_ip
            free_user_ip=$last_ip
            echo "free IP found - 10.10.10.$free_user_ip"
            echo "Writing CCD file for pushing static IP for the $user_name user"
            echo "ifconfig-push 10.10.10.$free_user_ip 10.10.10.$(($free_user_ip-1)) going to be stored in ${ccd_dir}/${user_name}"
            read -p "Are you sure? (Yes/No): " YesNo
            if [ $YesNo == "Yes" ] then
                touch $ccd_dir/$user_name
                echo "ifconfig-push 10.10.10.${free_user_ip} 10.10.10.$((${free_user_ip}-1))" > ${ccd_dir}/${user_name}
            fi

            ## Make certificates for the new user
            #  generate_new_cert
            echo "Going to generate certs for the ${user_name} user"
            read -p "Are you sure? (Yes/No): " YesNo
            if [ $YesNo == "Yes" ] then
                echo "Generating keys..."
                cd ${easy_rsa_dir}
                . ./vars
                ./pkitool $user_name
                echo "Certs are succesfully generated. "
                certificates_are_created=1
            fi

            ## create archive
            if [ $certificates_are_created == 1 ] then
                echo "Now I am going to create an archive that you could send to $user_name"
                mkdir -p ./keys/$user_name
                cp /etc/openvpn/keys/ca.crt ./keys/$user_name/
                cp /etc/openvpn/keys/ca.key ./keys/$user_name/
                cp /etc/openvpn/easy-rsa/keys/$user_name.crt ./keys/$user_name/
                cp /etc/openvpn/easy-rsa/keys/$user_name.key ./keys/$user_name/
                tar -zcvf ./keys/$user_name.tar.gz ./keys/$user_name
                rm -rf ./keys/$user_name
                echo "Archive $user_name.tar.gz is created. You can get it at $(pwd)/keys directory."
                echo ""

            fi

            ## TODO:
            #  send archive to the user

            ## generate and add a new rule into iptables
            echo "and the latest thind I have to do is adding an iptables rule"
            echo "next string will be added to the top of iptables table: "
            echo "iptables -I FORWARD 1 -s 10.10.10.$free_user_ip/32 -d 10.66.59.0/24 -p tcp -m tcp --dport 22 -j ACCEPT"
            echo "BUT! Which is more important the active iptables file will be copied to iptables.$(date +"%d%m%Y").bkp file"
            read -p "Are you sure? (Yes/No): " YesNo
            if [ $YesNo == "Yes" ] then
                iptables-save > /etc/sysconfig/iptables.$(date +"%d%m%Y").bkp
                iptables -I FORWARD 1 -s 10.10.10.$free_user_ip/32 -d 10.66.59.0/24 -p tcp -m tcp --dport 22 -j ACCEPT
                iptables-save > /etc/sysconfig/iptables
            fi
        fi
    fi
}

function usage {
 cat << EOF
 Usage: $0 [OPTIONS] user.name

EOF
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main $@
fi
