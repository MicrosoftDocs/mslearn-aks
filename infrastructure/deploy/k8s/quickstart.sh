#!/bin/bash

clusterAksName=${CLUSTER_NAME}
clusterSubs=${CLUSTER_SUBS}
clusterRg=${CLUSTER_RG}
clusterLocation=${CLUSTER_LOCATION}
learnAcrName=learn-aks-registry

while [ "$1" != "" ]; do
    case $1 in
        -s | --subscription)            shift
                                        clusterSubs=$1
                                        ;;
        -g | --resource-group)          shift
                                        clusterRg=$1
                                        ;;
        -n | --name)                    shift
                                        clusterAksName=$1
                                        ;;
        -l | --location)                shift
                                        clusterLocation=$1
                                        ;;
             * )                        echo "Invalid param: $1"
                                        exit 1
    esac
    shift
done

if [ -z "$clusterAksName" ]
then
    echo "${newline}${errorStyle}ERROR: AKS cluster name is mandatory. Use -n to set it.${defaultTextStyle}${newline}"
    exit 1
fi

if [ -z "$clusterRg" ]
then
    echo "${newline}${errorStyle}ERROR: Resource group is mandatory. Use -g to set it.${defaultTextStyle}${newline}"
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

export CLUSTER_NAME=$clusterAksName
export CLUSTER_SUBS=$clusterSubs
export CLUSTER_RG=$clusterRg
export CLUSTER_LOCATION=$clusterLocation
export LEARN_REGISTRY=$learnAcrName
export LEARN_QUICKSTART=true

cd ~/clouddrive/mslearn-aks/infrastructure/deploy/k8s

# AKS Cluster creation
. create-aks.sh

eval $(cat ~/clouddrive/mslearn-aks/create-aks-exports.txt)

# Deploy applications
# ./deploy-aks.sh