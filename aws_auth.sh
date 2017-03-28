#!/usr/bin/env bash

############################################################################################
# Authenticate to AWS against an ADFS Endpoint
# Your credentials will be exported into your current session as aws environment variables
#############################################################################################

provider="urn:amazon:webservices"

##Get current OS user
currentIdpUser=${idpUser:-$(whoami)}
#AD FS end point
idpHost=${idpHost:-exampleadfs.com}
idpUser=${currentIdpUser}
idpDomain=${idpDomain:-yourADDomain}
defaultRegion=${defaultRegion:-ap-southeast-2}
#Validate ssl certificate on endpoint, set it to false on dev environments against self signed certificates
validatessl=false
# Set ENDPOINT for ADFS authentication
endPoint="https://${idpHost}/adfs/ls/IdpInitiatedSignOn.aspx?loginToRp=${provider}"

function aws_get_account_alias() {
  #If you want to give accounts custom names just add them below as per the example list
  local aliases="ExampleAlias:292741327746 ExampleAlias2:499110692018"
  local name
  local number

  for i in $aliases
  do
    name=$(cut -d: -f1 <<< $i)
    number=$(cut -d: -f2 <<< $i)
    [[ "$1" == "$number" ]] && echo $name && return
    [[ "$1" == "$name" ]] && echo $number && return
  done

  echo "Aws"
}

function aws_auth() {
  unset AWS_DEFAULT_REGION
  roles=""

  if $validatessl ; then
      ssl_param=""
  else
      ssl_param="--no-check-certificate"
  fi

  # create temporary file to store ADFS request call
  tmp=$(mktemp /tmp/adfs.XXXX)

  echo "** Authenticating against ADFS server: $idpHost (if wrong, set idpHost) **"

  # Ask for username allowing default OS user
  read -p "Username or press enter for default (${idpUser}) : " idpUser
  [[ -z "$idpUser" ]] && idpUser=${currentIdpUser}

  # ask for AD password
  read -s -p "Password for ${idpDomain}\\${idpUser} : " idpPasswd
  echo
  ## ensure username / password don't show in process list
  creds=$(mktemp /tmp/adfs.c.XXXX)
  cat << EOF > $creds
userName=${idpDomain}%5C${idpUser}&Password=${idpPasswd}&AuthMethod=FormsAuthentication
EOF
  unset idpPasswd

  ## Authenticate against ADFS
  wget -q $ssl_param --post-file="${creds}" ${endPoint} -O $tmp
  wget_code=$?
  rm -f $creds

  if [ $wget_code -ne 0 ]; then
    echo "Error trying to authenticate against $idpHost" >&2
  elif grep -q -i "Sign In" $tmp
  then
    echo "Authentication Failed" >&2
  else
    # Search for SAMLResponse element on xml response
    SAMLResponse=$(xmllint --xpath "string(/html/body/form/*[@name='SAMLResponse']/@value)" $tmp)
    echo $SAMLResponse | base64 --decode > $tmp

    # Check how many roles have been created on AD (Ad groups) from the response
    count=$(xmllint --xpath 'count(//*[@Name="https://aws.amazon.com/SAML/Attributes/Role"]/*)' $tmp)

    # Walk the roles and store them in roles variable together with the saml response
    for i in $(seq 1 $count)
    do
      roles="$roles\n$(xmllint --xpath '(//*[@Name="https://aws.amazon.com/SAML/Attributes/Role"]/*)['${i}']/text()' $tmp)"
    done

    roles=$(echo -e $roles | sort -t ':' -k 5,12 | uniq | sed '/^[[:space:]]*$/d' | grep -v `aws_get_account_alias`)

    #prepare role names to be presented to the user in format rolename(accoutid)
    rolesMenu=$( echo $roles | tr ' ' '\n' | awk -F ":" 'BEGIN { account=0 } /\w+/ { if (account != $5) { account=$5; printf ";"account; }; printf "__"$NF}' | sed 's#role/##g;s#^;##' )

    #Show menu selection only when users have more than one role associated in AD
    if [ $count -gt 1 ]; then
      echo
      local counter=1
      for i in $(echo $rolesMenu | sed 's/;/ /g')
      do
        local account=$(awk -F '__' '{print $1}' <<< $i)
        echo " * $(aws_get_account_alias $account) account - $account"

        for j in $(echo $i | sed 's/__/ /g')
        do
          if [[ "$j" != "$account" ]]
          then
            echo -e "\t[$((counter++))] $j"
          fi
        done
        echo
      done

      read -p "Select which role you want to use [1 to $((counter - 1))]: " selection
      while [[ $selection -gt $((counter - 1)) ]] || [[ $selection -lt 1 ]]
      do
        read -p "  Valid selection are from 1 to $((counter - 1)): " selection
      done

      select_role=$(awk '{print $'$selection'}' <<< $roles)
    elif [[ $count -eq 1 ]]
    then
      select_role=$(echo -e $roles)
    else
      echo "error: no roles found. Ensure you're in the right groups on $idpHost (AD replication might take some time...)"
      return
    fi

    account=$(awk -F ':' '{ print $5}' <<< $select_role)
    echo
    echo "Assuming role $(awk -F 'role/' '{print $2}' <<< $select_role) in $(aws_get_account_alias $account) - $account ..."

    #Authenticate using aws sts to get temporarly credentials assuming the selected role
    credentials="$(aws sts assume-role-with-saml --principal-arn $(echo $select_role | awk -F ',' '{print $1}') --role-arn $(echo $select_role | awk -F ',' '{print $2}') --saml-assertion $SAMLResponse)"

    if [ $? -ne 0 ]; then
      echo "Error trying to authenticate against aws, you might not have aws roles created for your windows AD group" >&2
    else
      ## Unset all AWS variables
      aws_logout

      #Export AWS_* variables on user profile so they can start using the cli
      export AWS_ACCESS_KEY_ID="$(echo $credentials | jq '.Credentials.AccessKeyId' | sed 's/"//g')"
      export AWS_SECRET_ACCESS_KEY="$(echo $credentials | jq '.Credentials.SecretAccessKey' | sed 's/"//g')"
      export AWS_SESSION_TOKEN="$(echo $credentials | jq '.Credentials.SessionToken' | sed 's/"//g')"
      export AWS_USER_ID=${idpUser}
      export AWS_ACCOUNT=$account
      export AWS_DEFAULT_REGION=$defaultRegion
      echo "-----------------------------------------------------------------------------"
      echo "Your Aws credentials have been exported, you can now start using the AWS cli"
      echo "-----------------------------------------------------------------------------"
    fi
  fi
  rm -f $TMP
}

function aws_logout() {
  for var in $(env | awk -F '=' '/AWS_/ {print $1}')
  do
    # Don't knock out the default region
    [[ "$var" == "AWS_DEFAULT_REGION" ]] && continue
    unset $var
  done
}
