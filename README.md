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

- Set the required environtment variables the script needs to work:

  IDPHOST = (mandatory) this is the adfs endpoint

  ```
  IDPHOST=youridphost.com
  ```

  IPDOMAIN = (mandatory) The AD domain used by ADFS

  ```
  IPDOMAIN=yourADDomain
  ```

  DEFAULT_REGION = (Optional), By default it will use ap-southeast-2 but you can change it to your desired region

  ```
  DEFAULT_REGION=us-east-1
  ```

- Clone the repository, source the bash file and execute the main funciton:

  ```
  git clone git@github.com:oerazo/aws_auth.git
  cd aws_auth
  source ./aws_auth.sh
  aws_auth
  ```

  Follow the prompts...

### If you want to source the script permanently
Add  **source <absolutepath>/aws_auth.sh**
into your *~/.bash_profile* file then you would just need to run **aws_auth**

## Todo
  - Build a docker container so that we dont have to worry about dependencies
  - Add support for MFA
  - I know.. I could do it in python or other languages, the main reason for bash is that I can export the environment variables directly and start using the aws cli without having to think about profiles, however I will be adding a python version in the near future.
  - Pull requests are more than welcome
