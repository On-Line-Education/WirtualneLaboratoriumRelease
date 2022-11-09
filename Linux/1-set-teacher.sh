#!/bin/bash
### INPUT DATA ###
# $1 - token
# $2 - app server
# $3 - studentVpnName
# $4 - teacherVpnName

# assign user to teacher group
curl --request POST \
--header "Authorization: ${1}" \
--header 'content-type: application/json' \
--url "http://${2}/api" \
--data '{"query":"mutation ChangeUserGroupToTeacher($studentVpnName: String, $teacherVpnName: String) {\n  changeUserGroupToTeacher(studentVpnName: $studentVpnName, teacherVpnName: $teacherVpnName)\n}","variables":{"studentVpnName":"'${3}'","teacherVpnName":"'${4}'"}}'

# if fails returns null