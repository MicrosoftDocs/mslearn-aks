# This script expects the following environment variables:
# moduleName, gitBranch, gitUser
# eg. declare moduleName="learn-aks-deploy-helm"

# Common Declarations
declare scriptPath=https://raw.githubusercontent.com/$gitUser/mslearn-aks/$gitBranch/infrastructure/scripts
declare dotnetScriptsPath=$scriptPath/dotnet
declare gitDirectoriesToClone="infrastructure/deploy/ modules/$moduleName/src/"
declare gitPathToCloneScript=https://raw.githubusercontent.com/$gitUser/mslearn-aks/$gitBranch/infrastructure/setup/sparsecheckout.sh

if ! [ $rootLocation ]; then
    declare rootLocation=~
fi

declare subscriptionId=$(az account show --query id -o tsv)
declare resourceGroupName=""

# Functions
configureDotNetCli() {
    echo "${newline}${headingStyle}Configuring the .NET Core CLI...${defaultTextStyle}"
    declare installedDotNet=$(dotnet --version)

    if [ "$dotnetSdkVersion" != "$installedDotNet" ]; then
        # Install .NET Core SDK
        wget -q -O - https://dot.net/v1/dotnet-install.sh | bash /dev/stdin --version $dotnetSdkVersion
    else 
        echo ".NET Core SDK version $dotnetSdkVersion already installed."
    fi

    setPathEnvironmentVariableForDotNet

    # By default, the .NET Core CLI prints Welcome and Telemetry messages on
    # the first run. Suppress those messages by creating an appropriately
    # named file on disk.
    touch ~/.dotnet/$dotnetSdkVersion.dotnetFirstUseSentinel

    # Suppress priming the NuGet package cache with assemblies and 
    # XML docs we won't need.
    export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=true
    echo "export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=true" >> ~/.bashrc
    export NUGET_XMLDOC_MODE=skip
    echo "export NUGET_XMLDOC_MODE=skip" >> ~/.bashrc
    
    # Disable the sending of telemetry to the mothership.
    export DOTNET_CLI_TELEMETRY_OPTOUT=true
    echo "export DOTNET_CLI_TELEMETRY_OPTOUT=true" >> ~/.bashrc
    
    # Add tab completion for .NET Core CLI
    tabSlug="#dotnet-tab-completion"
    tabScript=$dotnetScriptsPath/tabcomplete.sh
    if ! [[ $(grep $tabSlug ~/.bashrc) ]]; then
        echo $tabSlug >> ~/.bashrc
        wget -q -O - $tabScript >> ~/.bashrc
        . <(wget -q -O - $tabScript)
    fi
    
    # Generate developer certificate so ASP.NET Core projects run without complaint
    dotnet dev-certs https --quiet
}

setPathEnvironmentVariableForDotNet() {
    # Add a note to .bashrc in case someone is running this in their own Cloud Shell
    echo "# The following was added by Microsoft Learn $moduleName" >> ~/.bashrc

    # Add .NET Core SDK and .NET Core Global Tools default installation directory to PATH
    if ! [ $(echo $PATH | grep .dotnet) ]; then 
        export PATH=~/.dotnet:~/.dotnet/tools:$PATH; 
        echo "# Add custom .NET Core SDK to PATH" >> ~/.bashrc
        echo "export PATH=~/.dotnet:~/.dotnet/tools:\$PATH;" >> ~/.bashrc
    fi
}

downloadAndBuild() {
    # Set location
    cd $rootLocation

    # Set global Git config variables
    git config --global user.name "Microsoft Learn Student"
    git config --global user.email learn@contoso.com
    
    # Download the sample project, restore NuGet packages, and build
    echo "${newline}${headingStyle}Downloading code...${defaultTextStyle}"
    (
        set -x
        wget -q -O - $gitPathToCloneScript | bash -s $gitDirectoriesToClone
    )
    echo "${defaultTextStyle}"
}

addVariablesToStartup() {
    if ! [[ $(grep $variableScript ~/.bashrc) ]]; then
        echo "${newline}# Next line added at $(date) by Microsoft Learn $moduleName" >> ~/.bashrc
        echo ". ~/$variableScript" >> ~/.bashrc
    fi 
}

displayGreeting() {
    # Set location
    cd ~

    # Display installed .NET Core SDK version
    if ! [ "$installDotNet" ]; then
        echo "${defaultTextStyle}Using .NET Core SDK version ${headingStyle}$dotnetSdkVersion${defaultTextStyle}"
    fi
}

determineResourceGroup() {
    # Figure out the name of the resource group to use
    declare existingResourceGroup=$(az group list | jq '.[] | select(.tags."x-created-by"=="freelearning").name' --raw-output)

    # If there is more than one RG or there's only one but its name is not a GUID,
    # we're probably not in the Learn sandbox.
    if [ "$existingResourceGroup" = "" ]; then
        echo "${warningStyle}WARNING!!!" \
            "It appears you aren't currently running in a Microsoft Learn sandbox." \
            "Any Azure resources provisioned by this script will result in charges" \
            "to your Azure subscription.${defaultTextStyle}"
        resourceGroupName="$moduleName-rg"
    else
        resourceGroupName=$existingResourceGroup
    fi

    echo "Using Azure resource group ${azCliCommandStyle}$resourceGroupName${defaultTextStyle}."
}

checkForCloudShell() {
    # Check to make sure we're in Azure Cloud Shell
    if [ "${AZURE_HTTP_USER_AGENT:0:11}" != "cloud-shell" ]; then
        echo "${warningStyle}WARNING!!!" \
            "It appears you aren't running this script in an instance of Azure Cloud Shell." \
            "This script was designed for the environment in Azure Cloud Shell, and we can make no promises that it'll function as intended anywhere else." \
            "Please only proceed if you know what you're doing.${newline}${newline}" \
            "Do you know what you're doing?${defaultTextStyle}"
        select yn in "Yes" "No"; do
            case $yn in
                Yes ) break;;
                No ) echo "${warningStyle}Please let us know that you saw this message using the feedback links provided.${defaultTextStyle}"; return 0;;
            esac
        done
    fi
}

# Load the theme
declare themeScript=$scriptPath/theme.sh
. <(wget -q -O - $themeScript)

# Execute functions
checkForCloudShell

# Check if resource group is needed 
if [ $suppressAzureResources != true ]; then
    determineResourceGroup
fi

if  ! [ -z "$installDotNet" ] && [ $installDotNet == true ]; then
    configureDotNetCli
else
    setPathEnvironmentVariableForDotNet
fi

displayGreeting

# Additional setup in setup.sh occurs next.
