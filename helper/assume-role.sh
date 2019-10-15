#!/bin/bash

session_name="SECURITYCLISESSION"
# Use the account alias here, e.g. "foobar-mgmt"
org_master="FILL_ME"
accounts_file="~/.aws/accounts"

RO_ROLE="AWSLandingZoneReadOnlyExecutionRole"
RW_ROLE="AWSLandingZoneSecurityAdministratorRole"

function as_get_org_accounts() {
  account_id=$(jq -r ".[\"${org_master}\"]" ${accounts_file})
  temp_role=$(aws sts assume-role \
                  --role-arn "arn:aws:iam::${account_id}:role/${RO_ROLE}" \
                  --role-session-name "${session_name}")

  export AWS_ACCESS_KEY_ID=$(echo $temp_role     | jq -r .Credentials.AccessKeyId)
  export AWS_SECRET_ACCESS_KEY=$(echo $temp_role | jq -r .Credentials.SecretAccessKey)
  export AWS_SESSION_TOKEN=$(echo $temp_role     | jq -r .Credentials.SessionToken)

  aws organizations list-accounts  --query 'Accounts[*]' | jq 'reduce .[] as $i ({}; .[$i.Name] = $i.Id)' > ${accounts_file}
}


function as_switch_account() {
  account_name_input=$1
  role_input=$2

  account_id=$(jq -r ".[\"${account_name_input}\"]" ${accounts_file})
  role_name=""

  if [ $account_id = null ]; then
    echo "id for account name ${account_name_input} not found" >&2
    exit 1
  fi

      if [ "${role_input}" = "rw" ] ; then
        role_name=${RW_ROLE}
      else
        role_name=${RO_ROLE}
      fi

  unset  AWS_SESSION_TOKEN

#
# TODO
# switch für readonly & readwrite
#
  temp_role=$(aws sts assume-role \
                      --role-arn "arn:aws:iam::${account_id}:role/${role_name}" \
                      --role-session-name "${session_name}")

  export AWS_ACCESS_KEY_ID=$(echo $temp_role     | jq -r .Credentials.AccessKeyId)
  export AWS_SECRET_ACCESS_KEY=$(echo $temp_role | jq -r .Credentials.SecretAccessKey)
  export AWS_SESSION_TOKEN=$(echo $temp_role     | jq -r .Credentials.SessionToken)
}

#
#  Iterate over each account and run the function which resides under
#  EXECME. Yes, not the best design decision, but dynamic ;-)
# 
#~ ❯❯❯ function foo() { ls }
#~ ❯❯❯ EXECME=foo
#~ ❯❯❯ function bar() { $EXECME }
# 
function as_exec_all() {
  OLD_ACCES_KEY=""
  OLD_SECRET_ACCESS_KEY=""
  OLD_SESSION_TOKEN=""

  for account_id in $(jq -r ".[]" ~/.aws/test) ; do 
    echo "-> ${account_id}" 
    temp_role=$(aws sts assume-role \
                    --role-arn "arn:aws:iam::${account_id}:role/${RO_ROLE}" \
                    --role-session-name "${session_name}")

  OLD_ACCES_KEY=${AWS_ACCESS_KEY_ID}
  OLD_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
  OLD_SESSION_TOKEN=${AWS_SESSION_TOKEN}

  export AWS_ACCESS_KEY_ID=$(echo $temp_role     | jq -r .Credentials.AccessKeyId)
  export AWS_SECRET_ACCESS_KEY=$(echo $temp_role | jq -r .Credentials.SecretAccessKey)
  export AWS_SESSION_TOKEN=$(echo $temp_role     | jq -r .Credentials.SessionToken)

  $EXECME

  AWS_ACCESS_KEY_ID=${OLD_ACCES_KEY}
  AWS_SECRET_ACCESS_KEY=${OLD_SECRET_ACCESS_KEY}
  AWS_SESSION_TOKEN=${OLD_SESSION_TOKEN}

  done
}

