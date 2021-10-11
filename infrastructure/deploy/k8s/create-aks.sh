#!/bin/bash

# Color theming
if [ -f ~/clouddrive/learn-aks/infrastructure/deploy/theme.sh ]
then
  . <(cat ~/clouddrive/learn-aks/infrastructure/deploy/theme.sh)
fi


clusterAksName=${CLUSTER_NAME}
clusterSubs=${CLUSTER_SUBS}
clusterRg=${CLUSTER_RG}
clusterLocation=${CLUSTER_LOCATION}
clusterNodeCount=${CLUSTER_NODECOUNT:-1}
learnRegistry=${LEARN_REGISTRY}
learnAcrName=${LEARN_ACRNAME}
clusterClientId=${LEARN_CLIENTID}
clusterClientSecret=${LEARN_CLIENTSECRET}

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
        -n | --name)                    shift
                                        clusterAksName=$1
                                        ;;
             --acr-name)                shift
                                        learnAcrName=$1
                                        ;;
            --appid)                   shift
                                       clusterClientId=$1
                                       ;;
            --password)                shift
                                       clusterClientSecret=$1
                                       ;;
             * )                        echo "Invalid param: $1"
                                        exit 1
    esac
    shift
done

if [ -z "$clusterRg" ]
then
    echo "${newline}${errorStyle}ERROR: resource group is mandatory. Use -g to set it.${defaultTextStyle}${newline}"
    exit 1
fi

if [ -z "$clusterAksName" ]&&[ -z "$LEARN_QUICKSTART" ]
then
    echo "${newline}${errorStyle}ERROR: AKS cluster name is mandatory. Use -n to set it.${defaultTextStyle}${newline}"
    exit 1
fi

if [ -z "$learnAcrName" ]&&[ -z "$LEARN_QUICKSTART" ]
then
    echo "${newline}${errorStyle}ERROR: ACR name is mandatory. Use --acr-name to set it.${defaultTextStyle}${newline}"
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

# Swallow STDERR so we don't get red text here from expected error if the RG doesn't exist
exec 3>&2
exec 2> /dev/null

rg=`az group show -g $clusterRg -o json`

# Reset STDERR
exec 2>&3

if [ -z "$rg" ]
then
    if [ -z "$clusterSubs" ]
    then
        echo "${newline}${errorStyle}ERROR: If resource group has to be created, location is mandatory. Use -l to set it.${defaultTextStyle}${newline}"
        exit 1
    fi
    echo "Creating resource group $clusterRg in location $clusterLocation..."
    echo "${newline} > ${azCliCommandStyle}az group create -n $clusterRg -l $clusterLocation --output none${defaultTextStyle}${newline}"
    az group create -n $clusterRg -l $clusterLocation --output none
    if [ ! $? -eq 0 ]
    then
        echo "${newline}${errorStyle}ERROR: Can't create resource group!${defaultTextStyle}${newline}"
        exit 1
    fi
else
    if [ -z "$clusterLocation" ]
    then
        clusterLocation=`az group show -g $clusterRg --query "location" -o tsv`
    fi
fi



# AKS Cluster creation
echo
echo "Creating AKS cluster \"$clusterAksName\" in resource group \"$clusterRg\" and location \"$clusterLocation\"..."
aksCreateCommand="az aks create -n $clusterAksName -g $clusterRg --node-count $clusterNodeCount --node-vm-size Standard_B2s --vm-set-type VirtualMachineScaleSets -l $clusterLocation --enable-managed-identity --generate-ssh-keys -o json"
echo "${newline} > ${azCliCommandStyle}$aksCreateCommand${defaultTextStyle}${newline}"
retry=5
aks=`$aksCreateCommand`
while [ ! $? -eq 0 ]&&[ $retry -gt 0 ]&&[ ! -z "$spHomepage" ]
do
    echo
    echo "Not yet ready for AKS cluster creation. ${bold}This is normal and expected.${defaultTextStyle} Retrying in 5s..."
    let retry--
    sleep 5
    echo
    echo "Retrying AKS cluster creation..."
    aks=`$aksCreateCommand`
done

if [ ! $? -eq 0 ]
then
    echo "${newline}${errorStyle}Error creating AKS cluster!${defaultTextStyle}${newline}"
    exit 1
fi

echo
echo "AKS cluster created."

if [ ! -z "$learnAcrName" ]
then
    echo
    echo "Granting AKS pull permissions from ACR $learnAcrName"
    az aks update -n $clusterAksName -g $clusterRg --attach-acr $learnAcrName
fi

echo
echo "Getting credentials for AKS..."
az aks get-credentials -n $clusterAksName -g $clusterRg --overwrite-existing

# Ingress controller and load balancer (LB) deployment

echo
echo "Installing NGINX ingress controller"
kubectl apply -f ingress-controller/nginx-controller.yaml
 kubectl apply -f ingress-controller/nginx-loadbalancer.yaml

echo
echo "Getting load balancer public IP"

aksNodeRGCommand="az aks list --query \"[?name=='$clusterAksName'&&resourceGroup=='$clusterRg'].nodeResourceGroup\" -o tsv"

retry=5
echo "${newline} > ${azCliCommandStyle}$aksNodeRGCommand${defaultTextStyle}${newline}"
aksNodeRG=$(eval $aksNodeRGCommand)
while [ -z "$aksNodeRG" ]
do
    echo
    echo "Unable to obtain load balancer resource group. Retrying in 5s..."
    let retry--
    sleep 5
    echo
    echo "Retrying..."
    echo $aksNodeRGCommand
    aksNodeRG=$(eval $aksNodeRGCommand)
done


while [ -z "$aksLbIp" ] || [ "$aksLbIp" == "<pending>" ]
do
    aksLbIp=`kubectl get svc/ingress-nginx -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`
    if [ -z "$aksLbIp" ]
    then
        echo "Waiting for the Load Balancer IP address - Ctrl+C to cancel..."
        sleep 5
    else
        echo "Assigned IP address: $aksLbIp"
    fi
done

echo
echo "Nginx ingress controller installed."

echo export CLUSTER_NAME=$clusterAksName > create-aks-exports.txt
echo export CLUSTER_SUBS=$clusterSubs >> create-aks-exports.txt
echo export CLUSTER_RG=$clusterRg >> create-aks-exports.txt
echo export CLUSTER_LOCATION=$clusterLocation >> create-aks-exports.txt
echo export CLUSTER_AKSNODERG=$aksNodeRG >> create-aks-exports.txt
echo export CLUSTER_LBIP=$aksLbIp >> create-aks-exports.txt

if [ ! -z "$learnAcrName" ]
then
    echo export LEARN_ACRNAME=$learnAcrName >> create-aks-exports.txt
fi

if [ ! -z "$learnRegistry" ]
then
    echo export LEARN_REGISTRY=$learnRegistry >> create-aks-exports.txt
fi

if [ ! -z "$spHomepage" ]
then
   echo export LEARN_CLIENTID=$clusterClientId >> create-aks-exports.txt
   echo export LEARNCLIENTPASSWORD=$clusterClientSecret >> create-aks-exports.txt
fi

if [ -z "$LEARN_QUICKSTART" ]
then
    echo "Run the following command to update the environment"
    echo 'eval $(cat ~/clouddrive/mslearn-aks/create-aks-exports.txt)'
    echo
fi

mv -f create-aks-exports.txt ~/clouddrive/mslearn-aks/