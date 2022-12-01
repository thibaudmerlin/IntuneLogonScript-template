# Intune LogonScript FunctionApp

- Azure Function App to serve as midddleware for a logon script solution for cloud managed devices.
- Special thanks to you guys : https://github.com/tabs-not-spaces/Intune.Logonscript.FunctionApp for the initial repo and ideas
- Logon, Install and Uninstall scripts provided

# Updates (thibaud.merlin Kyos)
- Change Extension bundle from 1.*, 2.0.0 to 2.*, 3.0.0
- Add printers support in schema, function and logonscript
- Add unistall script

# Use printers in the script
- Don't forget to set up point and print restriction by configuring theses parameters with an Intune config policies, otherwise users will be prompted each time the script try to install a printer
![image](https://user-images.githubusercontent.com/107478270/201037325-43bfcd4d-9a28-4878-b723-4eb174fc69bf.png)
- You need at least one printer in the json, just put NOUSER as group and it should be ok

# Installation
## 1. Create App Registration
- Create a new App Registration in AzureAD, name Company-LogonScript (Single Tenant, no redirect uri)
- Add API permissions : Directory.Read.All (application), Group.Read.All (application)
- Create a secret and save the value
- Save the Client(app) ID, save the Tenant ID

## 2. Create an Azure Function
![image](https://user-images.githubusercontent.com/107478270/202448508-069eb0e6-a4ec-4e92-8bd7-a393fc10611c.png)
- Add App Insight to monitor the function
- Create a slot for UAT
- Create environment variables for PRD and UAT (in configuration) :
    - client_id = yourclientID
    - client_secret = yourclientSecret
    - tenant_id = yourtenantID
- *Optional : you can enforce certificate auth in the azure function in strict env.
## 3. Clone the github repo
- Clone this repository
- *Optional : Create the env. variable for pipeline

## 4. Customize the files for the customer and deploy the function
- Connect VSCode to the GitHub repo
- Add desired drives and printers in driveMaps.json (respect the schema)
- Don't forget to let at least one printer, even if it's not used (use for ex. NOUSER as group)
- Deploy the function to UAT by using Azure Functions:Deploy to Slot... in VSCode
- If tests are ok, deploy it to PRD by using Azure Functions:Deploy to Function App... in VSCode
- Gather the function URI and save it
- Change variable in Logon.ps1, Install.ps1 and UnInstall.ps1 ($client, $fileServer, $funcUri)

## 5. Create the win32 app and upload it to Intune
- Donwload [win32 prep tool](https://github.com/Microsoft/Microsoft-Win32-Content-Prep-Tool)
- Put all the files into the logonscript folder in the intunewin package
- Deploy the App in intune and use the commands :
    - Install Command : Powershell.exe -NoProfile -ExecutionPolicy ByPass -File .\Install.ps1
    - Uninstall Command : Powershell.exe -NoProfile -ExecutionPolicy ByPass -File .\UnInstall.ps1
# Folder overview

- function-app contains the function app code that will be deployed to Azure
- logonscript contains the code that will be packaged and deployed via Intune
- tests contains the pester tests to be used for interactive testing OR ci/cd deployment

# Pre-Reqs for local function app development and deployment

To develop and deploy the function app contained within this repository, please make sure you have the following reqs on your development environment.

- [Visual Studio Code](https://code.visualstudio.com/)
- The [Azure Functions Core Tools](https://docs.microsoft.com/en-us/azure/azure-functions/functions-run-local#install-the-azure-functions-core-tools) version 2.x or later. The Core Tools package is downloaded and installed automatically when you start the project locally. Core Tools includes the entire Azure Functions runtime, so download and installation might take some time.
- [PowerShell 7](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-windows) recommended.
- Both [.NET Core 3.1](https://www.microsoft.com/net/download) runtime and [.NET Core 2.1 runtime](https://dotnet.microsoft.com/download/dotnet-core/2.1).
- The [PowerShell extension for Visual Studio Code](https://marketplace.visualstudio.com/items?itemName=ms-vscode.PowerShell).
- The [Azure Functions extension for Visual Studio Code](https://docs.microsoft.com/en-us/azure/azure-functions/functions-develop-vs-code?tabs=powershell#install-the-azure-functions-extension)
- The [Pester Tests extension for Visual Studio Code](https://marketplace.visualstudio.com/items?itemName=pspester.pester-test)
- The [Pester Tests Explorer extension for Visual Studio Code](https://marketplace.visualstudio.com/items?itemName=TylerLeonhardt.vscode-pester-test-adapter)
