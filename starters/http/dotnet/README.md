# Azure Functions

## Starter template (HTTP Triggered .NET 8 Isolated C# Functions, Flex Consumption)

This sample template provides an "empty starting point" function that is ready to run and deploy Azure easily.  

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://github.com/codespaces/new?hide_repo_select=true&ref=main&repo=575770869)

## Run on your local environment

### Pre-reqs

1) [.NET 8 SDK](https://dotnet.microsoft.com/en-us/download/dotnet/8.0) 
2) [Azure Functions Core Tools](https://learn.microsoft.com/en-us/azure/azure-functions/functions-run-local?tabs=v4%2Cmacos%2Ccsharp%2Cportal%2Cbash#install-the-azure-functions-core-tools)

4) Start Azurite storage emulator. See [this page](https://learn.microsoft.com/azure/storage/common/storage-use-azurite) for how to configure and start the Azurite emulator for Local Storage.

### Using Functions CLI

1) Open a new terminal and do the following:

```bash
cd http
func start
```

2) Test a Web hook or GET using the browser to open http://localhost:7071/api/http

3) Test a POST using your favorite REST client, e.g. [RestClient in VS Code](https://marketplace.visualstudio.com/items?itemName=humao.rest-client), PostMan, curl.  `test.http` has been provided to run this quickly.

Terminal:

```bash
curl -i -X POST http://localhost:7071/api/httppostbody \
  -H "Content-Type: text/json" \
  --data-binary "@testdata.json"
```

testdata.json

```json
{
    "person": 
    {
        "name": "Awesome Developer",
        "age": 25 
    }
}
```

test.http

```bash

POST http://localhost:7071/api/httppostbody HTTP/1.1
content-type: application/json

{
    "person": 
    {
        "name": "Awesome Developer",
        "age": 25 
    }
}
```

### Using Visual Studio

1) Open `starter.sln` using Visual Studio 2022 or later.
2) Press Run/F5 to run in the debugger
3) Use same approach above to test using an HTTP REST client

### Using Visual Studio Code

1) Open this folder in a new terminal
2) Open VS Code by entering `code .` in the terminal
3) Press Run/Debug (F5) to run in the debugger
4) Use same approach above to test using an HTTP REST client

## Source Code

The key code that makes this work is as follows in `./http/httpGetFunction.cs` and `./http/httpGetFunction.cs`.  The async Run function is marked as an Azure Function using the Function attribute and naming `http`.  This code shows how to handle an ordinary Web hook GET or a POST that sends
a `name` value in the request body as JSON.  

```csharp
[Function("httpget")]
public IActionResult Run([HttpTrigger(AuthorizationLevel.Anonymous, "get")] HttpRequest req)
{
    return new OkObjectResult("Welcome to Azure Functions!");
}
```

```csharp
[Function("httppostbody")]        
public IActionResult Run([HttpTrigger(AuthorizationLevel.Anonymous, "post")] HttpRequest req,
    [FromBody] Person person)
{
    return new OkObjectResult(person);
}
```

## Deploy to Azure

The easiest way to deploy this app is using the [Azure Dev CLI aka AZD](https://aka.ms/azd).  If you open this repo in GitHub CodeSpaces the AZD tooling is already preinstalled.

To provision:

```bash
azd up
```

Note that `azd deploy` and Visual Studio does not yet work to publish Flex Consumption apps. Please use Azure Functions Core Tools, Az CLI or VS Code alternatives instead to deploy your app zip to these Flex resources.