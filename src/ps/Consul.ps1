# Load the System.Web assembly otherwise Powershell can't find the System.Web.HttpUtility class
Add-Type -AssemblyName System.Web

<#
    .SYNOPSIS

    Converts the base-64 encoded value to the original data.


    .DESCRIPTION

    The ConvertFrom-ConsulEncodedValue function converts the base-64 encoded value to the original data.


    .PARAMETER encodedValue

    The base-64 encoded data.


    .OUTPUTS

    The decoded data.
#>
function ConvertFrom-ConsulEncodedValue
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $encodedValue
    )

    Write-Verbose "ConvertFrom-ConsulEncodedValue - encodedValue: $encodedValue"

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $PSBoundParameters.ContainsKey('Debug');
            ErrorAction = "Stop"
        }

    return [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($encodedValue))
}

<#
    .SYNOPSIS

    Converts the value into a base-64 encoded string.


    .DESCRIPTION

    The ConvertTo-ConsulEncodedValue function converts the value into a base-64 encoded string.


    .PARAMETER encodedValue

    The input data.


    .OUTPUTS

    The base-64 encoded data.
#>
function ConvertTo-ConsulEncodedValue
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $value
    )

    Write-Verbose "ConvertTo-ConsulEncodedValue - value: $value"

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $PSBoundParameters.ContainsKey('Debug');
            ErrorAction = "Stop"
        }

    return [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($value))
}

<#
    .SYNOPSIS

    Gets the data center for the given environment.


    .DESCRIPTION

    The Get-ConsulDataCenter function gets the data center for the given environment


    .PARAMETER consulLocalAddress

    The URL to the local consul agent.


    .OUTPUTS

    The data center for the given environment.
#>
function Get-ConsulDataCenter
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $consulLocalAddress = "http://localhost:8500"
    )

    Write-Verbose "Get-ConsulDataCenter - consulLocalAddress: $consulLocalAddress"

    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $PSBoundParameters.ContainsKey('Debug');
            ErrorAction = "Stop"
        }

    $kvSubUrl = Get-UrlRelativePathForEnvironmentKeyValuesForConsul `
        -consulLocalAddress $consulLocalAddress `
        @commonParameterSwitches

    $consulDataCenter = Get-ConsulKeyValue `
        -consulLocalAddress $consulLocalAddress `
        -keyPath "$($kvSubUrl)/datacenter" `
        @commonParameterSwitches

    return $consulDataCenter
}

<#
    .SYNOPSIS

    Gets the domain that the consul DNS nodes listen to.


    .DESCRIPTION

    The Get-ConsulDomain function gets domain that the consul DNS nodes listen to, e.g. .consul.


    .PARAMETER consulLocalAddress

    The URL to the local consul agent.


    .OUTPUTS

    The domain that the consul nodes listen to.
#>
function Get-ConsulDomain
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $consulLocalAddress = "http://localhost:8500"
    )

    Write-Verbose "Get-ConsulDomain - consulLocalAddress: $consulLocalAddress"

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $PSBoundParameters.ContainsKey('Debug');
            ErrorAction = "Stop"
        }

    $nodeSelfUri = "$($consulLocalAddress)/v1/agent/self"
    $response = Invoke-WebRequest -Uri $nodeSelfUri -UseBasicParsing -UseDefaultCredentials @commonParameterSwitches
    $json = ConvertFrom-Json -InputObject $response @commonParameterSwitches

    return $json.Domain
}

<#
    .SYNOPSIS

    Gets the value for a given key from the key-value storage on a given data center.


    .DESCRIPTION

    The Get-ConsulKeyValue function gets the value for a given key from the key-value storage on a given data center.


    .PARAMETER consulLocalAddress

    The URL to the local consul agent.


    .PARAMETER keyPath

    The path to the key for which the value is to be retrieved.


    .OUTPUTS

    The data that was stored under the given key.
#>
function Get-ConsulKeyValue
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $consulLocalAddress = "http://localhost:8500",

        [ValidateNotNullOrEmpty()]
        [string] $keyPath
    )

    Write-Verbose "Get-ConsulKeyValue - consulLocalAddress: $consulLocalAddress"
    Write-Verbose "Get-ConsulKeyValue - keyPath: $keyPath"

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $PSBoundParameters.ContainsKey('Debug');
            ErrorAction = "Stop"
        }

    $keyUri = "$($consulLocalAddress)/v1/kv/$($keyPath)"
    $keyResponse = Invoke-WebRequest -Uri $keyUri -UseBasicParsing -UseDefaultCredentials @commonParameterSwitches
    $json = ConvertFrom-Json -InputObject $keyResponse @commonParameterSwitches
    $value = ConvertFrom-ConsulEncodedValue -encodedValue $json.Value @commonParameterSwitches

    return $value
}

<#
    .SYNOPSIS

    Gets the IP address of the node providing the given service.


    .DESCRIPTION

    The Get-ResourceNamesForService function gets the IP address of the node providing the given service.


    .PARAMETER consulLocalAddress

    The URL to the local consul agent.


    .PARAMETER service

    The name of the service


    .PARAMETER tag

    The (optional) tag.


    .OUTPUTS

    The IP or address of the node that provides the service.
#>
function Get-ResourceNamesForService
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $consulLocalAddress = "http://localhost:8500",

        [ValidateNotNullOrEmpty()]
        [string] $service,

        [ValidateNotNull()]
        [string] $tag = ''
    )

    Write-Verbose "Get-ResourceNamesForService - consulLocalAddress: $consulLocalAddress"
    Write-Verbose "Get-ResourceNamesForService - service: $service"
    Write-Verbose "Get-ResourceNamesForService - tag: $tag"

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $PSBoundParameters.ContainsKey('Debug');
            ErrorAction = "Stop"
        }

    $serviceUri = "$($consulLocalAddress)/v1/catalog/service/$($service)"
    if ($tag -ne '')
    {
        $serviceUri += "?tag=$([System.Web.HttpUtility]::UrlEncode($tag))"
    }

    $serviceResponse = Invoke-WebRequest -Uri $serviceUri -UseBasicParsing -UseDefaultCredentials @commonParameterSwitches
    $json = ConvertFrom-Json -InputObject $serviceResponse @commonParameterSwitches
    $serviceAddress = $json[0].Address

    return $serviceAddress
}

<#
    .SYNOPSIS

    Adds an external service to the given consul environment.


    .DESCRIPTION

    The Set-ConsulExternalService function adds an external service to the given consul environment


    .PARAMETER httpUrl

    The URL to one of the consul agents. Defaults to the localhost address.


    .PARAMETER dataCenter

    The URL to the local consul agent.


    .PARAMETER serviceName

    The name of the service that should be added.


    .PARAMETER serviceUrl

    The URL of the service that should be added.
#>
function Set-ConsulExternalService
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $httpUrl = "http://localhost:8500",

        [ValidateNotNullOrEmpty()]
        [Parameter(ParameterSetName='ByUrl')]
        [string] $dataCenter,

        [ValidateNotNullOrEmpty()]
        [string] $serviceName,

        [ValidateNotNullOrEmpty()]
        [string] $serviceUrl
    )

    $url = $httpUrl
    $dc = $dataCenter

    $value = @"
{
  "Datacenter": "$dataCenter",
  "Node": "$serviceName",
  "Address": "$serviceUrl",
  "Service": {
    "Service": "$serviceName",
    "Address": "$serviceUrl"
  }
}
"@

    $uri = "$($url)/v1/catalog/register?dc=$([System.Web.HttpUtility]::UrlEncode($dc))"
    $response = Invoke-WebRequest -Uri $uri -Method Put -Body $value -UseBasicParsing -UseDefaultCredentials @commonParameterSwitches
    if ($response.StatusCode -ne 200)
    {
        throw "Failed to add external service [$serviceName - $serviceUrl] on [$dc]"
    }
}

<#
    .SYNOPSIS

    Sets a key-value pair on the given consul environment.


    .DESCRIPTION

    The Set-ConsulKeyValue function sets a key-value pair on the given consul environment.


    .PARAMETER httpUrl

    The URL to one of the consul agents. Defaults to the localhost address.


    .PARAMETER dataCenter

    The name of the data center for which the value should be set.


    .PARAMETER keyPath

    The path to the key that should be set


    .PARAMETER value

    The value that should be set.
#>
function Set-ConsulKeyValue
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $httpUrl = "http://localhost:8500",

        [ValidateNotNullOrEmpty()]
        [Parameter(ParameterSetName='ByUrl')]
        [string] $dataCenter,

        [ValidateNotNullOrEmpty()]
        [string] $keyPath,

        [ValidateNotNullOrEmpty()]
        [string] $value
    )

    $url = $httpUrl
    $dc = $dataCenter

    $uri = "$($url)/v1/kv/$($keyPath)?dc=$([System.Web.HttpUtility]::UrlEncode($dc))"

    Write-Verbose "Setting key-value pair at $(uri)"
    $response = Invoke-WebRequest -Uri $uri -Method Put -Body $value -UseBasicParsing -UseDefaultCredentials @commonParameterSwitches
    if ($response.StatusCode -eq 200)
    {
        Write-Verbose "Key-value pair successfully set at $uri"
    }
    else
    {
        throw "Failed to set Key-Value pair [$keyPath] - [$value] on [$dc]"
    }
}
