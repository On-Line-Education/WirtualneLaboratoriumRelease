#!/bin/bash
### INPUT DATA ###
# $1 - token
# $2 - app server
# $3 - studentVpnName
# $4 - hub
# $5 - teacherVpnName


VPN_PATH='/etc/NetworkManager/system-connections/LAB.nmconnection'
user=${3}
hub=${4}
teacher=${5}


# get veyon keys for student
pubkey=$(curl --request POST \
    --header "Authorization: ${1}" \
    --header 'content-type: application/json' \
    --url "http://${2}/api" \
    --data '{"query":"query GetVeyonKeys($hubName: String, $vpnname: String) {\n  getVeyonKeys(hubName: $hubName, vpnname: $vpnname) {\n    pubKey\n  }\n}","variables":{"hubName":"'${hub}'","vpnname":"'${teacher}'"}}' --silent | /usr/bin/jq -r '.[].getVeyonKeys.pubKey') 

# save public key to file
echo -e "${pubkey}" > /tmp/.veyon-pub.pem

# clear existing auth keys from Veyon
veyon-cli authkeys delete test/private
veyon-cli authkeys delete test/public

# import public key to Veyon
veyon-cli authkeys import test/public /tmp/.veyon-pub.pem
veyon-cli authkeys setaccessgroup test/public users
rm /tmp/.veyon-pub.pem

# get pre-shared key for VPN
vpnpsk=$(curl --request POST \
    --header "Authorization: ${1}" \
    --header 'content-type: application/json' \
    --url "http://${2}/api" \
    --data '{"query":"query Query {\n  getIpSec {\n    IPsec_Secret_str\n  }\n}"}' --silent | /usr/bin/jq -r '.data[].IPsec_Secret_str')

# get vpn password for user
reply=$(curl --request POST \
    --header "Authorization: ${1}" \
    --header 'content-type: application/json' \
    --url "http://${2}/api" \
    --data '{"query":"query GetTeachersInUserGroups($vpnname: String,$hubname: String) {\n  getTeachersInUserGroups(vpnname: $vpnname, hubname: $hubname) {\n    user {\n      vpnLogin\n      vpnPass\n    }\n  }\n}","variables":{"vpnname":"'${user}'","hubname":"'${hub}'"}}' --silent)

# set credentials
vpnlogin="${user}@${hub}"
vpnpassword=$(echo "${reply}" | /usr/bin/jq -r '.[].getTeachersInUserGroups[].vpnPass')

# alter user's Full Name so that it's displayed in Veyon as user's login
usermod -c "${user}" geeko

/usr/local/vpnclient/vpnclient start
/usr/local/vpnclient/vpncmd localhost /CLIENT /CMD AccountDisconnect lab
/usr/local/vpnclient/vpncmd localhost /CLIENT /CMD NicDelete "VPN"
/usr/local/vpnclient/vpncmd localhost /CLIENT /CMD NicCreate "VPN"
/usr/local/vpnclient/vpncmd localhost /CLIENT /CMD AccountDelete lab
/usr/local/vpnclient/vpncmd localhost /CLIENT /CMD AccountCreate lab /SERVER:$(echo ${2} | cut -d: -f1):5555 /HUB:${hub} /USERNAME:${user} /NICNAME:VPN
/usr/local/vpnclient/vpncmd localhost /CLIENT /CMD AccountPasswordSet lab /PASSWORD:"${vpnpassword}" /TYPE:standard
/usr/local/vpnclient/vpncmd localhost /CLIENT /CMD AccountStatusHide lab
/usr/local/vpnclient/vpncmd localhost /CLIENT /CMD AccountConnect lab
sleep 1
dhclient vpn_vpn
ok=false
time=0
while [[ $ok == "false" && $time -le 15 ]];do 
    ip -4 -br a | grep ^vpn_vpn | awk '{print $3 }' | grep '192.168' && ok=true; 
    time=$[$time + 1];
    sleep 1;
done

if [[ $ok == "true" ]];then
    echo "confok"
else
    echo "conferr"
    ip route delete default via 192.168.30.1 dev vpn_vpn
    resolvectl revert vpn_vpn
    exit
fi

ip route delete default via 192.168.30.1 dev vpn_vpn
resolvectl revert vpn_vpn

# restart Veyon service to reload auth keys
systemctl restart veyon.service
