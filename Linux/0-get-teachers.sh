#!/bin/bash
### INPUT DATA ###
# $1 - token
# $2 - app server
# $3 - username
# $4 - password

# get user data:
# name
# username
# role
# hub
reply=$(curl --request POST \
    --header "Authorization: ${1}" \
    --header 'content-type: application/json' \
    --url "http://${2}/api" \
    --data '{"query":"query LoginViaPassword($username: String, $password: String) {\n  loginViaPassword(username: $username, password: $password) {\n    user {\n      name\n      username\n      role\n      hubs\n    }\n  }\n}","variables":{"username":"'${3}'","password":"'${4}'"}}' --silent)

# extract data into variables
login=$(echo ${reply} | /usr/bin/jq -r '.data[].user.username')
role=$(echo ${reply} | /usr/bin/jq -r '.data[].user.role')
hub=$(echo ${reply} | /usr/bin/jq -r '.data[].user.hubs[0]')
username=$(echo ${reply} | /usr/bin/jq -r '.data[].user.name')

# check role, if instructor, then print only their data
if [[ ${role} == "instructor" ]];then 
    echo "teacher:${login}:${hub}:${username}"
else
# create temporary file, it will be returned to Desktop App later
file=$(mktemp)
# add student data to the beginning of the file
echo "student:${login}:${hub}:${username}" > $file

# get all teachers with common groups for a student
reply=$(curl --request POST \
    --header "Authorization: ${1}" \
    --header 'content-type: application/json' \
    --url "http://${2}/api" \
    --data '{"query":"query GetTeachersInUserGroups($vpnname: String, $hubname: String) {\n  getTeachersInUserGroups(vpnname: $vpnname, hubname: $hubname) {\n    teachers {\n      name\n     username\n    }\n  }\n}","variables":{"vpnname":"'${username}'","hubname":"'${hub}'"}}' --silent)

# extract data and append it to file
echo $reply | /usr/bin/jq -r '.data[].teachers[].username' >> $file
echo $reply | /usr/bin/jq -r '.data[].teachers[].name' >> $file

# print and remove file
cat $file
rm $file
fi
