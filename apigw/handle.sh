#!/bin/bash

#set -eux

# CAVEATS
# Integration in CF template must be  set to POST, even if it is a GET for real
# See
# https://forums.aws.amazon.com/thread.jspa?threadID=209420
# or way shorter
# https://forums.aws.amazon.com/thread.jspa?threadID=240699
#

# The template is based upon
# https://github.com/reiki4040/postslack-cloudformation

STACK=LambdaTest
REGION=eu-central-1
FILE=gateway.json
CFCMD="aws cloudformation --region $REGION"
APCMD="aws apigateway     --region $REGION"
STAGE=dev

function create() {
    $CFCMD create-stack    \
        --stack-name "$STACK" \
        --template-body file://"$FILE" \
        --capabilities CAPABILITY_IAM
    
    $CFCMD wait stack-create-complete --stack-name "$STACK"
    info
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

function getkeyid() {
    info | jq -r '.Stacks[].Outputs[] | select(.OutputKey == "apikeyid").OutputValue'
}

function getweburl() { 
    info | jq -r '.Stacks[].Outputs[] | select(.OutputKey == "url").OutputValue'
}

function getapiid() {
    info | jq -r '.Stacks[].Outputs[] | select(.OutputKey == "api").OutputValue'
}

function getusageplan() {
    info | jq -r '.Stacks[].Outputs[] | select(.OutputKey == "usageplan").OutputValue'
}

function getkeyval() {
    if [ $# != 1 ]; then
        local ID=$(getkeyid)
    else
        local ID=$1
    fi
    $APCMD get-api-key --api-key "$ID" --include-value | jq -r '.value'
}

function getlatestkey() {
    getkeyval "$($APCMD get-api-keys | jq -r '.items[0].id')"
}

function deploy() {
    echo "IMPLEMENT ME"
}

function addapikey() {
    local KEYID=$($APCMD create-api-key \
    --name $1 \
    --description $2 \
    --enabled \
    --stage-keys restApiId="$(getapiid)",stageName="$STAGE" | jq -r ".id" )

    $APCMD create-usage-plan-key \
        --usage-plan-id $(getusageplan) \
        --key-type "API_KEY" \
        --key-id "$KEYID"

    getkeyval "$KEYID"
}

# Keys are sorted with the youngest first
#
function encrypt() {
    getlatestkey | gpg --encrypt --recipient $1
    
}

function symencrypt() {
    getlatestkey | gpg --armor --symmetric --cipher-algo AES256
}

function printtest() {
    echo "curl  -vvv -H 'x-api-key : $(getkeyval)' $(getweburl) | less"
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
  -y) # deploy the api
    deploy
    ;;
  -t) # print the test curl command
    printtest
    ;;
  -k) # get the API key
    getkeyval
    ;;
  -w) # get the URL for the endpoint
    getweburl
    ;;
  -x) # encrypt the last created API key
    encrypt $2
    ;;
  -xs) # symmetrically encrypt the last created API key
    symencrypt
    ;;
  -a) # add an API key with parameter: <KEYNAME> <DESCRIPTION>
    if [ $# != 3 ]; then
        echo "Usage: \"$0\" <KEYNAME> <DESCRIPTION>" >&2
        exit 1
    fi
    addapikey $2 $3
    ;;
   *)
    echo "$0 - handle lambda cloudformation templates"
    egrep -- "-.*\)\s*\#" $0
    ;;
esac