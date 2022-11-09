param(
[Parameter (Mandatory = $true)] [String]$Token,
[Parameter (Mandatory = $true)] [String]$Login,
[Parameter (Mandatory = $true)] [String]$Password,
[Parameter (Mandatory = $true)] [String]$Server
)
$head = @{"Authorization"="${Token}"}
$body = '{"query":"query LoginViaPassword($username: String, $password: String) {\n  loginViaPassword(username: $username, password: $password) {\n    user {\n      name\n      username\n      role\n      hubs\n    }\n  }\n}","variables":{"username":"'+${Login}+'","password":"'+${Password}+'"}}'
$response=Invoke-WebRequest -Method Post -Headers $head -ContentType 'application/json' -UseBasicParsing -Body $body -Uri http://${Server}/api -TimeoutSec 10 -ErrorAction Stop


if ($response.StatusCode -notcontains "200") {
        Write-Error "CONN_ERR" -ErrorAction Stop
    }

if($response -like '*UNAUTHENTICATED*')
{
	Write-Error 'UNAUTHENTICATED' -ErrorAction Stop
}

$vpnLogin=($response.Content | ConvertFrom-Json | Select -Expand data | Select -Expand loginViaPassword | Select -Expand user).name
$role=($response.Content | ConvertFrom-Json | Select -Expand data | Select -Expand loginViaPassword | Select -Expand user).role
$hub=($response.Content | ConvertFrom-Json | Select -Expand data | Select -Expand loginViaPassword | Select -Expand user).hubs[0]
$username=($response.Content | ConvertFrom-Json | Select -Expand data | Select -Expand loginViaPassword | Select -Expand user).username

if($role -eq 'instructor') 
{
    Write-Host "teacher:${username}:${hub}:${vpnLogin}"
}
else
{
    Write-Host "student:${username}:${hub}:${vpnLogin}"
    $body='{"query":"query GetTeachersInUserGroups($vpnname: String, $hubname: String) {\n  getTeachersInUserGroups(vpnname: $vpnname, hubname: $hubname) {\n    teachers {\n      name\n     username\n    }\n  }\n}","variables":{"vpnname":"'+${vpnLogin}+'","hubname":"'+${hub}+'"}}'
    $response=Invoke-WebRequest -Method Post -Headers $head -ContentType 'application/json' -UseBasicParsing -Body $body -Uri http://${Server}/api

    $teachers=$response.Content | ConvertFrom-Json | Select -Expand data | Select -Expand getTeachersInUserGroups | Select -Expand teachers

    #$teachers | ForEach-Object {$_.name}
    foreach($name in $teachers){
        Write-Host $name.username
    }

    foreach($name in $teachers){
        Write-Host $name.name
    }
}