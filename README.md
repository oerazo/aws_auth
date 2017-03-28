## Adfs authentication
Authenticate to AWS using an ADFS endpoint.

## Dependencies
As this solution has been built using bash it requires a couple of components so that we can read the saml response:
  - Install xmllint

    *Note: xmllint comes from libxml package.*

  - Install [jq](https://stedolan.github.io/jq/download/)

  - Make sure you have [wget](https://www.gnu.org/software/wget/) installed  

  - Install [awscli](http://docs.aws.amazon.com/cli/latest/userguide/installing.html)

## How to use

- Set the required environment variables the script needs to work:

  idpHost = (mandatory) this is the adfs endpoint

  ```
  idpHost=youridphost.com
  ```

  idpDomain = (mandatory) The AD domain used by ADFS

  ```
  idpDomain=yourADDomain
  ```

  defaultRegion = (Optional), By default it will use ap-southeast-2 but you can change it to your desired region

  ```
  defaultRegion=us-east-1
  ```

- Clone the repository, source the bash file and execute the main funciton:

  ```
  git clone git@github.com:oerazo/aws_auth.git
  cd aws_auth
  source ./aws_auth.sh
  aws_auth
  ```

  Follow the prompts...

### If you want to source the script permanently and set the variables
Add  **source <absolutepath>/aws_auth.sh**
into your *~/.bash_profile* file then you would just need to run **aws_auth**, this is an example .bash_profile content :

```
idpHost=adfs.domain.com.au
idpDomain=exampledomain
source ~/projects/bash_adfs/aws_auth.sh  
```

## Todo
  - Have an option to run it on a docker container
  - Add support for MFA
  - Pull requests are welcome
