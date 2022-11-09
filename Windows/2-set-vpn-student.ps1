param(
[Parameter (Mandatory = $true)] [String]$Token,
[Parameter (Mandatory = $true)] [String]$User,
[Parameter (Mandatory = $true)] [String]$Teacher,
[Parameter (Mandatory = $true)] [String]$Hub,
[Parameter (Mandatory = $true)] [String]$Server
)
$head = @{"Authorization"="${Token}"}
veyon-cli authkeys delete test/public
veyon-cli authkeys delete test/private
# get Veyon key
$body='{"query":"query GetVeyonKeys($hubName: String, $vpnname: String) {\n  getVeyonKeys(hubName: $hubName, vpnname: $vpnname) {\n    pubKey\n  }\n}","variables":{"hubName":"'+${Hub}+'","vpnname":"'+${Teacher}+'"}}'
$response=Invoke-WebRequest -Method Post -Headers $head -ContentType 'application/json' -UseBasicParsing -Body $body -Uri http://${Server}/api

$pubKey=($response.Content | ConvertFrom-Json | Select -Expand data | Select -Expand getVeyonKeys).pubKey
${pubKey} | Out-File -Filepath "C:\.veyon-pub.pem" -append -width 200

veyon-cli authkeys import test/public C:\.veyon-pub.pem
veyon-cli authkeys setaccessgroup test/public users

Remove-Item -Path "C:\.veyon-pub.pem"

# get PreShared Key
$body='{"query":"query Query {\n  getIpSec {\n    IPsec_Secret_str\n  }\n}"}'
$response=Invoke-WebRequest -Method Post -Headers $head -ContentType 'application/json' -UseBasicParsing -Body $body -Uri http://${Server}/api
$psk=($response.Content | ConvertFrom-Json | Select -Expand data | Select -Expand getIpSec).IPsec_Secret_str
Write-Host "${psk}"

# get VPN login and password
$body='{"query":"query GetTeachersInUserGroups($vpnname: String, $hubname: String) {\n  getTeachersInUserGroups(vpnname: $vpnname, hubname: $hubname) {\n    user {\n      vpnLogin\n      vpnPass\n    }\n  }\n}","variables":{"vpnname":"'+${User}+'","hubname":"'+${Hub}+'"}}'
$response=Invoke-WebRequest -Method Post -Headers $head -ContentType 'application/json' -UseBasicParsing -Body $body -Uri http://${Server}/api

$vpnLogin=($response.Content | ConvertFrom-Json | Select -Expand data | Select -Expand getTeachersInUserGroups | Select -Expand user).vpnLogin
$vpnPass=($response.Content | ConvertFrom-Json | Select -Expand data | Select -Expand getTeachersInUserGroups | Select -Expand user).vpnPass

Write-Host "${vpnLogin}:${vpnPass}"

vpncmd.exe localhost /CLIENT /CMD AccountDisconnect lab

vpncmd.exe localhost /CLIENT /CMD NicUpgrade "VPN"

Get-NetIPInterface | Where-Object {$_.InterfaceAlias -like "VPN*"} | Set-NetIPInterface -InterfaceMetric 9999 

vpncmd.exe localhost /CLIENT /CMD AccountDelete lab

vpncmd.exe localhost /CLIENT /CMD AccountCreate lab /SERVER:${Srv}:5555 /HUB:${Hub} /USERNAME:${vpnLogin} /NICNAME:VPN

vpncmd.exe localhost /CLIENT /CMD AccountPasswordSet lab /PASSWORD:"${vpnPass}" /TYPE:standard

vpncmd.exe localhost /CLIENT /CMD AccountStatusHide lab

Start-Sleep -Seconds 1

vpncmd.exe localhost /CLIENT /CMD AccountConnect lab

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
}

#Remove-VpnConnection -connectionname LAB -Force
#Add-VpnConnection -ServerAddress vpn.oedu.pl -RememberCredential -Name LAB -TunnelType L2tp -L2tpPsk $psk -Force
#Set-VpnConnectionUsernamePassword -connectionname LAB -username $vpnLogin@$Hub -password $vpnPass
Restart-Service VeyonService
