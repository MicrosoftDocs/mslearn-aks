#!/bin/bash

# Color theming
if [ -f ~/clouddrive/learn-aks/infrastructure/deploy/theme.sh ]
then
  . <(cat ~/clouddrive/learn-aks/infrastructure/deploy/theme.sh)
fi


if [ -f ~/clouddrive/mslearn-aks/create-aks-exports.txt ]
then
  eval $(cat ~/clouddrive/mslearn-aks/create-aks-exports.txt)
fi

learnAcrName=${LEARN_REGISTRY}
clusterAksName=${CLUSTER_NAME}
clusterSubs=${CLUSTER_SUBS}
clusterRg=${CLUSTER_RG}
clusterLocation=${CLUSTER_LOCATION}
acrIdTag=${CLUSTER_IDTAG}

while [ "$1" != "" ]; do
    case $1 in
        -s | --subscription)            shift
                                        clusterSubs=$1
                                        ;;
        -g | --resource-group)          shift
                                        clusterRg=$1
                                        ;;
        -l | --location)                shift
                                        clusterLocation=$1
                                        ;;
             --aks-name)                shift
                                        clusterAksName=$1
                                        ;;
             --acr-name)                shift
                                        learnAcrName=$1
                                        ;;
             * )                        echo "Invalid param: $1"
                                        exit 1
    esac
    shift
done

if [ -z "$clusterAksName" ]&&[ -z "$LEARN_QUICKSTART" ]
then
    echo "${newline}${errorStyle}ERROR: AKS cluster name is mandatory. Use --aks-name to set it.${defaultTextStyle}${newline}"
    exit 1
fi

if [ -z "$learnAcrName" ]&&[ -z "$LEARN_QUICKSTART" ]
then
    echo "${newline}${errorStyle}ERROR: ACR name is mandatory. Use --acr-name to set it.${defaultTextStyle}${newline}"
    exit 1
fi

if [ -z "$clusterRg" ]
then
    echo "${newline}${errorStyle}ERROR: Resource group is mandatory. Use -g to set it${defaultTextStyle}${newline}"
    exit 1
fi

if [ ! -z "$clusterSubs" ]
then
    echo "Switching to subscription $clusterSubs..."
    az account set -s $clusterSubs
fi

if [ ! $? -eq 0 ]
then
    echo "${newline}${errorStyle}ERROR: Can't switch to subscription $clusterSubs.${defaultTextStyle}${newline}"
    exit 1
fi

rg=`az group show -g $clusterRg -o json`

if [ -z "$rg" ]
then
    if [ -z "$clusterLocation" ]
    then
        echo "${newline}${errorStyle}ERROR: If resource group has to be created, location is mandatory. Use -l to set it.${defaultTextStyle}${newline}"
        exit 1
    fi
    echo "Creating RG $clusterRg in location $clusterLocation..."
    az group create -n $clusterRg -l $clusterLocation
    if [ ! $? -eq 0 ]
    then
        echo "${newline}${errorStyle}ERROR: Can't create resource group${defaultTextStyle}${newline}"
        exit 1
    fi

    echo "Created RG \"$clusterRg\" in location \"$clusterLocation\"."

else
    if [ -z "$clusterLocation" ]
    then
        clusterLocation=`az group show -g $clusterRg --query "location" -o tsv`
    fi
fi

# ACR Creation

learnAcrName=${LEARN_ACRNAME}

if [ -z "$learnAcrName" ]
then

    if [ -z "$acrIdTag" ]
    then
        dateString=$(date "+%Y%m%d%H%M%S")
        random=`head /dev/urandom | tr -dc 0-9 | head -c 3 ; echo ''`

        acrIdTag="$dateString$random"
    fi

    echo
    echo "Creating Azure Container Registry aksacrlearn$acrIdTag in resource group $clusterRg..."
    acrCommand="az acr create --name aksacrlearn$acrIdTag -g $clusterRg -l $clusterLocation -o json --sku basic --admin-enabled --query \"name\" -o tsv"
    echo "${newline} > ${azCliCommandStyle}$acrCommand${defaultTextStyle}${newline}"
    learnAcrName=`$acrCommand`

    if [ ! $? -eq 0 ]
    then
        echo "${newline}${errorStyle}ERROR creating ACR!${defaultTextStyle}${newline}"
        exit 1
    fi

    echo ACR created!
    echo
fi

learnRegistry=`az acr show -n $learnAcrName --query "loginServer" -o tsv`

if [ -z "$learnRegistry" ]
then
    echo "${newline}${errorStyle}ERROR! ACR server $learnAcrName doesn't exist!${defaultTextStyle}${newline}"
    exit 1
fi

learnAcrCredentials=`az acr credential show -n $learnAcrName --query "[username,passwords[0].value]" -o tsv`
learnAcrUser=`echo "$learnAcrCredentials" | head -1`
learnAcrPassword=`echo "$learnAcrCredentials" | tail -1`

# Grant permisions to AKS if created
learnAks=`az aks show -n $clusterAksName -g $clusterRg`

if [ ! -z "$learnAks" ]
then
    echo "Attaching ACR to AKS..."
    attachCmd="az aks update -n $clusterAksName -g $clusterRg --attach-acr $learnAcrName --output none" 
    echo "${newline} > ${azCliCommandStyle}$attachCmd${defaultTextStyle}${newline}"
    eval $attachCmd
fi

echo export CLUSTER_SUBS=$clusterSubs > create-acr-exports.txt
echo export CLUSTER_RG=$clusterRg >> create-acr-exports.txt
echo export CLUSTER_LOCATION=$clusterLocation >> create-acr-exports.txt
echo export LEARN_ACRNAME=$learnAcrName >> create-acr-exports.txt
echo export LEARN_REGISTRY=$learnRegistry >> create-acr-exports.txt
echo export LEARN_ACRUSER=$learnAcrUser >> create-acr-exports.txt
echo export LEARN_ACRPASSWORD=$learnAcrPassword >> create-acr-exports.txt
echo export CLUSTER_IDTAG=$acrIdTag >> create-acr-exports.txt

echo 
echo "Created Azure Container Registry \"$learnAcrName\" in resource group \"$clusterRg\" in location \"$clusterLocation\"." 

#mv -f create-acr-exports.txt ~/clouddrive/mslearn-aks/