param(
[Parameter (Mandatory = $true)] [String]$Token,
[Parameter (Mandatory = $true)] [String]$Teacher,
[Parameter (Mandatory = $true)] [String]$Hub,
[Parameter (Mandatory = $true)] [String]$Server
)

$Srv=${Server}.Split(":")[0].Trim()

$head = @{"Authorization"="${Token}"}

veyon-cli authkeys delete test/public
veyon-cli authkeys delete test/private

# get Veyon pub key
$body='{"query":"query GetVeyonKeys($hubName: String, $vpnname: String) {\n  getVeyonKeys(hubName: $hubName, vpnname: $vpnname) {\n    pubKey\n  }\n}","variables":{"hubName":"'+${Hub}+'","vpnname":"'+${Teacher}+'"}}'
$response=Invoke-WebRequest -Method Post -Headers $head -ContentType 'application/json' -UseBasicParsing -Body $body -Uri http://${Server}/api

$pubKey=($response.Content | ConvertFrom-Json | Select -Expand data | Select -Expand getVeyonKeys).pubKey
${pubKey} | Out-File -Filepath "C:\.veyon-pub.pem" -append -width 200
veyon-cli authkeys import test/public C:\.veyon-pub.pem
veyon-cli authkeys setaccessgroup test/public users

Remove-Item -Path "C:\.veyon-pub.pem"

# get Veyon priv key
$body='{"query":"query GetVeyonKeys($hubName: String, $vpnname: String) {\n  getVeyonKeys(hubName: $hubName, vpnname: $vpnname) {\n    privKey\n  }\n}","variables":{"hubName":"'+${Hub}+'","vpnname":"'+${Teacher}+'"}}'
$response=Invoke-WebRequest -Method Post -Headers $head -ContentType 'application/json' -UseBasicParsing -Body $body -Uri http://${Server}/api

$privKey=($response.Content | ConvertFrom-Json | Select -Expand data | Select -Expand getVeyonKeys).privKey
${privKey} | Out-File -Filepath "C:\.veyon-priv.pem" -append -width 200

veyon-cli authkeys import test/private C:\.veyon-priv.pem
veyon-cli authkeys setaccessgroup test/private users

Remove-Item -Path "C:\.veyon-priv.pem"

#echo -e "${pubkey}" > /tmp/.veyon-pub.pem
#veyon-cli authkeys import test/public /tmp/.veyon-pub.pem
#veyon-cli authkeys setaccessgroup test/public users

# get PreShared Key
$body='{"query":"query Query {\n  getIpSec {\n    IPsec_Secret_str\n  }\n}"}'
$response=Invoke-WebRequest -Method Post -Headers $head -ContentType 'application/json' -UseBasicParsing -Body $body -Uri http://${Server}/api
$psk=($response.Content | ConvertFrom-Json | Select -Expand data | Select -Expand getIpSec).IPsec_Secret_str

Write-Host $psk

# get VPN login and password
$body='{"query":"query GetTeachersInUserGroups($hubname: String, $vpnname: String) {\n  getTeachersInUserGroups(hubname: $hubname, vpnname: $vpnname) {\n    user {\n      vpnLogin\n      vpnPass\n    }\n  }\n}","variables":{"vpnname":"'+${Teacher}+'","hubname":"'+${Hub}+'"}}'
$response=Invoke-WebRequest -Method Post -Headers $head -ContentType 'application/json' -UseBasicParsing -Body $body -Uri http://${Server}/api

$vpnLogin=($response.Content | ConvertFrom-Json | Select -Expand data | Select -Expand getTeachersInUserGroups | Select -Expand user).vpnLogin
$vpnPass=($response.Content | ConvertFrom-Json | Select -Expand data | Select -Expand getTeachersInUserGroups | Select -Expand user).vpnPass

Write-Host $vpnLogin
Write-Host $vpnPass

vpncmd.exe localhost /CLIENT /CMD AccountDisconnect lab

vpncmd.exe localhost /CLIENT /CMD NicUpgrade "VPN"

Get-NetIPInterface | Where-Object {$_.InterfaceAlias -like "VPN*"} | Set-NetIPInterface -InterfaceMetric 9999 

vpncmd.exe localhost /CLIENT /CMD AccountDelete lab

vpncmd.exe localhost /CLIENT /CMD AccountCreate lab /SERVER:${Srv}:5555 /HUB:${Hub} /USERNAME:${vpnLogin} /NICNAME:VPN

vpncmd.exe localhost /CLIENT /CMD AccountPasswordSet lab /PASSWORD:"${vpnPass}" /TYPE:standard

vpncmd.exe localhost /CLIENT /CMD AccountStatusHide lab

Start-Sleep -Seconds 1

vpncmd.exe localhost /CLIENT /CMD AccountConnect lab

#ip=$(ip -4 -br a | grep '^ppp0' | awk '{ print $3 }' | cut -d. -f3)

$IP=(Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'VPN - VPN Client').IPAddress
$Time=0
while($IP -notlike "192.168*" -And $Time -le 15) {
    $IP=(Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'VPN - VPN Client').IPAddress
    Start-Sleep -Seconds 1
    $Time++
}

if($IP -Like "192.168*") {
	Write-Host "confok"
}
else {
	Write-Host "conferr"
    Exit
}
# $IP="192.168.30.10"

veyon-cli networkobjects clear
veyon-cli networkobjects add location klasa

for($i=10; $i -le 254; $i++) {
    if ( ${i} -notmatch $IP.Split(".")[3] )
    {
        veyon-cli networkobjects add computer host${i} 192.168.30.${i} "aa:bb:cc:dd:ee:ff" klasa
    }
}

Restart-Service VeyonService
