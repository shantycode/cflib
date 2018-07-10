API Key CloudFormation POC
===

A CloudFormation template to install lambdas with API keys. You can also add multiple API keys
and encrypt those with GPG.

# How to use

- Set up your AWS shell environment
- See handle.sh -h for usage ;-)

```
./handle.sh - handle lambda cloudformation templates
  -c) # create the stack
  -d) # delete the stack
  -u) # update the stack
  -i) # print the output variables
  -y) # deploy the api
  -t) # print the test curl command
  -k) # get the API key
  -w) # get the URL for the endpoint
  -x) # encrypt the last created API key
  -xs) # symmetrically encrypt the last created API key
  -a) # add an API key with parameter: <KEYNAME> <DESCRIPTION>

```

## Kudos

The CF template is based upon the work found here
https://github.com/reiki4040/postslack-cloudformation