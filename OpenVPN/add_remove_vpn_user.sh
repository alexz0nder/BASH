#!/bin/bash

function assign_variables {
    user_email=$1
    echo "user email is $user_email"
    user_name=$(cut -d'@' -f1 <<< "$user_email")
    user_domain=$(cut -d'@' -f2 <<< "$user_email")
    openvpn_home_dir="/etc/openvpn"
    easy_rsa_dir="$openvpn_home_dir/easy-rsa"
    ccd_dir="$openvpn_home_dir/ccd"
    sript_dir=$(pwd)


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

function ask_Yes_No() {
  read -p "$1 (Are you sure? [y]es or [N]o): " -n 1 -r
  if [[ $REPLY =~ ^(yes|y|Y| ) ]] || [[ -z $REPLY ]]; then
      echo 1
  else
      echo 0
  fi
}

function remove_old_user() {
    echo "there are already generated certificates and ccd file, so it might be you wanted to revoke certs for the user and clean all ends ? :)"
    if [ $(ask_Yes_No) == "1" ]; then
        ## Remove IPtables rule
        #
        user_ip_adress=$(cat ${ccd_dir}/${user_name} | cut -d' ' -f2)
        iptables_string=$(iptables -L --line-numbers | grep $user_ip_adress)
        iptables_line_number=$(echo "$iptables_string" | cut -d' ' -f1)
        echo "Okay."
        echo "Removing iptables line N $iptables_line_number:"
        echo $iptables_string
        if [ $(ask_Yes_No) == "1" ]; then
            iptables -D FORWARD $iptables_line_number
            iptables-save > /etc/sysconfig/iptables
            echo ""
            echo "iptables rule was succesfully deleted"
            echo ""
        else
            echo "Okay. But I had to ask just in case if you don't want to :)"
            echo ""
        fi

        ## Delete CCD file
        #
        echo "Now I am going to remove the user's CCD file"
        if [ $(ask_Yes_No) == "1" ]; then
            rm -f ${ccd_dir}/${user_name}
            echo ""
            echo "the CCD file was succesfully deleted"
        else
            echo "Okay. But I had to ask just in case if you don't want to :)"
            echo ""
        fi

        ## Revoke certs
        #
        echo "How about to revoke keys... ?"
        if [ $(ask_Yes_No) == "1" ]; then
            echo ""
            cd ${easy_rsa_dir}
            . ./vars
            ./revoke-full ${user_name}
            if ! [ -e ./revoked ]; then
                mkdir ./revoked
            fi
            mv ./keys/${user_name}* ./revoked/
            echo ""
        else
            echo "Okay. But I had to ask just in case if you don't want to :)"
            echo ""
        fi
    else
        echo "Okay. In case you change your mind just run this script again."
        echo ""
    fi
}

function add_new_user() {
    echo "So. There is neither already generated certificate nor ccd configured file for the user."
    echo "Searching for free IP..."
    echo ""
    find_free_ip
    free_user_ip=$last_ip

    echo "free IP found - 10.10.10.$free_user_ip"
    echo "Going to write CCD file for pushing static IP for the $user_name user with next content:"
    echo "ifconfig-push 10.10.10.$free_user_ip 10.10.10.$(($free_user_ip-1)) going to be stored in ${ccd_dir}/${user_name}"
    echo ""
    if [ $(ask_Yes_No) == "1" ]; then
        touch $ccd_dir/$user_name
        echo "ifconfig-push 10.10.10.${free_user_ip} 10.10.10.$((${free_user_ip}-1))" > ${ccd_dir}/${user_name}
        echo ""
    else
         echo "Okay. If you won't create the CCD file then exiting because there is no need to make neither iptables rules nor certificates... "
         exit 0
    fi

    ## Make certificates for the new user
    #  generate_new_cert
    echo "Going to generate certs for the ${user_name} user"
    if [ $(ask_Yes_No) == "1" ]; then
        echo "Generating keys..."
        cd ${easy_rsa_dir}
        . ./vars
        export KEY_EMAIL=$user_email
        ./pkitool $user_name
        echo "Certs are succesfully generated. "
        certificates_are_created="True"
    else
        echo "Okay. But I had to ask just in case if you don't want to :)"
    fi

    ## create archive
    if [[ $certificates_are_created == "True" ]]; then
        echo "Now I am going to create an archive that you could send to $user_name"
        cd $sript_dir
        mkdir -p ./keys/$user_name
        cp /etc/openvpn/keys/ca.crt ./keys/$user_name/
        cp /etc/openvpn/keys/ta.key ./keys/$user_name/
        cp /etc/openvpn/easy-rsa/keys/$user_name.crt ./keys/$user_name/
        cp /etc/openvpn/easy-rsa/keys/$user_name.key ./keys/$user_name/
        tar -zcvf ./keys/$user_name.tar.gz ./keys/$user_name
        rm -rf ./keys/$user_name

        if [ -e "./keys/$user_name.tar.gz" ]; then
            echo "Archive $user_name.tar.gz is created. You can get it at sript_dir directory."
            echo ""
        else
            echo "Something went wrong. Archive $user_name.tar.gz at $script_dir/keys wasn't made."
            echo ""
        fi
    else
        echo "Okay. But I had to ask just in case if you don't want to :)"
    fi

    ## TODO:
    #  send archive to the user

    ## generate and add a new rule into iptables
    echo "And the latest thind I have to do is to add an iptables rule."
    echo "Next string will be added to the top of iptables table: "
    echo "iptables -I FORWARD 1 -s 10.10.10.$free_user_ip/32 -d 10.66.59.0/24 -p tcp -m tcp --dport 22 -j ACCEPT"
    echo "And, which is also important, the active iptables going to be saved into the iptables.$(date +"%d%m%Y").bkp file"
    if [ $(ask_Yes_No) == "1" ]; then
        iptables-save > /etc/sysconfig/iptables.$(date +"%d%m%Y").bkp
        iptables -I FORWARD 1 -s 10.10.10.$free_user_ip/32 -d 10.66.59.0/24 -p tcp -m tcp --dport 22 -j ACCEPT
        iptables-save > /etc/sysconfig/iptables
        echo ""
    else
        echo "Okay. But I had to ask just in case if you don't want to :)"
        echo ""
    fi
}

function main {
    if [ $# -eq 0 ]; then
        usage
    else
        echo "Firstly we are going to split that email to a name and a domain:"
        assign_variables $@
        echo "name=${user_name} AT domain=${user_domain}"
        echo ""
        if [ -e "${easy_rsa_dir}/keys/${user_name}.crt" ] && [ -e "${ccd_dir}/${user_name}" ]; then
            remove_old_user
            exit 0
        else
            add_new_user
            exit 0
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
