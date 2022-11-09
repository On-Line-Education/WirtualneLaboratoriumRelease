param(
[Parameter (Mandatory = $true)] [String]$Token,
[Parameter (Mandatory = $true)] [String]$StudentName,
[Parameter (Mandatory = $true)] [String]$TeacherName,
[Parameter (Mandatory = $true)] [String]$Server
)

$head = @{"Authorization"="${Token}"}
$body='{"query":"mutation ChangeUserGroupToTeacher($studentVpnName: String, $teacherVpnName: String) {\n  changeUserGroupToTeacher(studentVpnName: $studentVpnName, teacherVpnName: $teacherVpnName)\n}","variables":{"studentVpnName":"'+${StudentName}+'","teacherVpnName":"'+${TeacherName}+'"}}'
$response=Invoke-WebRequest -Method Post -Headers $head -ContentType 'application/json' -UseBasicParsing -Body $body -Uri http://${Server}/api

$code=$response.Content | ConvertFrom-Json | Select -Expand data

Write-Host $code.changeUserGroupToTeacher