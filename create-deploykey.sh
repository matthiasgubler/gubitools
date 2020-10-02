#!/bin/bash
#
# This is a helper script to create the public private keypair to get machine access
# to your GitHub repository.
#
# * you can choose to create a OpenShift secret with the script
# * the public key is added to the github.axa.com repository
 
# define colors for output
GREEN="\e[0;32;40m"
RED="\e[1;31;40m"
YELLOW="\e[1;33;40m"
WHITE="\e[0m"
GITHUB="https://github.axa.com"
 
# read user input to name the public-private key and the OpenShift secret.
echo -e $YELLOW
echo -e "Enter the GitHub Organization and Repository to name the keys.$WHITE"
read -p "    Name of your github organization :" github_org
read -p "    Name of the github repository : " github_repo
file_crt_identifier="${github_org}-${github_repo}"
 
 
# create public-private keypair
# -t create a RSA key
# -b length of the key in bytes
# -C comment in the out
# -N passphrase, in our case empty
# -f output file
# -q quiet
ssh-keygen -q -t rsa -b 4096  -N '' -f $file_crt_identifier
echo "your public-private key pair is created"
echo "private key: '$file_crt_identifier'"
echo "public key: '$file_crt_identifier'.pub"
echo
 
 
# create openshift secret
echo -e $YELLOW
read -p "do you want to store your private key as a openshift secret? [y or n] " yn
echo -e $WHITE
if [[ $yn == "y" ]]
then
        openshift_key_identifier=`echo "github-${github_repo}-${github_org}" | tr '[:upper:]' '[:lower:]'`
        oc create secret generic ${openshift_key_identifier} --type='kubernetes.io/ssh-auth' --from-file=ssh-privatekey=${file_crt_identifier} --from-file=ssh-publickey=${file_crt_identifier}.pub
        if [ $? -eq 0 ]; then
                echo -e "$GREEN    OpenShift secret created, removing private key $WHITE"
		oc secret link builder secret/${openshift_key_identifier}
                rm $file_crt_identifier
        else
                echo -e "$RED    Failed to create OpenShift secrete $openshift_key_identifier in project $openshift_project $WHITE"
        fi
else
        echo -e "\n $RED keep your private key save! $WHITE \n"
fi
 
# how to add the key to github
echo -e $YELLOW
echo -e "Enter your GitHub credentials to upload the public key into the repository ${github_org}-${github_repo}.$WHITE"
read -p "    GitHub username (firstname-lastname) :" github_user
read -p "    Personal access token : " github_token
read -p "    Title of the Deploy-Key in the GitHub repository : " deploy_key
read -p "    Should the access be read-only? [y or n] : " yn
read_only=true
if [[ $yn == "n" ]]
then
        read_only=false
fi
 
generate_post_data()
{
  cat <<EOF
{
   "title":"${deploy_key}",
   "key":"`cat  ${file_crt_identifier}.pub`",
   "read_only":${read_only}
}
EOF
}
 
 
echo
echo "uploading deploy key "
curl -s -X POST --data "$(generate_post_data)" -u ${github_user}:${github_token} ${GITHUB}/api/v3/repos/${github_org}/${github_repo}/keys
if [ $? -eq 0 ]; then
        echo -e "$GREEN uploaded deploy key to  ${GITHUB}/${github_org}/${github_repo}/settings/keys $WHITE"
else
        echo -e "$RED failed to upload deploy key ${deploy_key} to  ${GITHUB}/${github_org}/${github_repo}/settings/keys $WHITE"
fi
 
echo
echo
