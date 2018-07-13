#!/bin/bash

#set -eux

STACK=EC2Test
REGION=eu-central-1
FILE=ec2.json
RAWDATA=userdata.raw
USERDATA=userdata.sh
CFCMD="aws cloudformation --region $REGION"

function create() {
    prepuserdata

    $CFCMD create-stack    \
        --stack-name "$STACK" \
        --template-body file://"$FILE" \
        --capabilities CAPABILITY_IAM \
        --parameters ParameterKey=UserData,ParameterValue=$(base64 -w0 "$USERDATA")
    
    $CFCMD wait stack-create-complete --stack-name "$STACK"
    info

    rm "$USERDATA"
}

function delete() {
    $CFCMD delete-stack --stack-name "$STACK"
    $CFCMD wait stack-delete-complete --stack-name "$STACK"
}

function update() {
    $CFCMD update-stack \
        --stack-name "$STACK" \
        --template-body file://"$FILE" \
        --capabilities CAPABILITY_IAM

    $CFCMD wait stack-update-complete --stack-name "$STACK"
    info
}

function info() {
    $CFCMD describe-stacks --stack-name "$STACK"
}

function validate() {
    $CFCMD validate-template --template-body "file://$FILE"
}

function prepuserdata() {
    key=$(ssh-add -L)
    # Remember, sed can also use different characters as delimiter
    sed "s@SSHKEY@$key@g" "$RAWDATA" > "$USERDATA"
}

function getinstanceid() {
    info | jq -r '.Stacks[].Outputs[] | select(.OutputKey == "instanceid").OutputValue'
}

function getip() { 
    info | jq -r '.Stacks[].Outputs[] | select(.OutputKey == "ip").OutputValue'
}

function getdns() {
    info | jq -r '.Stacks[].Outputs[] | select(.OutputKey == "dns").OutputValue'
}

function getaz() {
    info | jq -r '.Stacks[].Outputs[] | select(.OutputKey == "az").OutputValue'
}

# Stupid little lazy helper function
function getami() {
    aws ec2 describe-images --owners amazon \
    --query 'reverse(sort_by(Images[*].{Id:ImageId,Type:VirtualizationType,Created:CreationDate,Storage:RootDeviceType, Desc:Description}, &Created))' \
    --filters "Name=description,Values=Amazon Linux AMI*" \
    --output table --region eu-central-1 | grep 2018
}

case "$1" in
  -c) # create the stack
    create
    ;;
  -d) # delete the stack
    delete
    ;;
  -u) # update the stack
    update
    ;;
  -i) # print the output variables
    info
    ;;
  -v) # validate the template
    validate
    ;;
  -p) # prepares the userdata file, see the function
    prepuserdata
    ;;
   *)
    echo "$0 - handle lambda cloudformation templates"
    egrep -- "-.*\)\s*\#" $0
    ;;
esac