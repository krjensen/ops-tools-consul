<#
    The following functions assume that there is at least one environment which describes
    the other environments, the meta environment. This environment knows about the other
    environments and how to find them.

    The expected layout of the Consul key value store for an environment is:

    v1
        kv
            environment
                self - The name of the current environment
                meta
                    consul
                        number_of_servers - The number of consul servers in the current environment

                        <CONSUL_SERVER_NUMBER_0>
                            datacenter   - Name of datacenter
                            http         - Full URL (including port) of the HTTP connection
                            serf_wan     - Full URL (including port) of the Serf connection for consul instance on the WAN

                            [NOTE] The following key-value entries are only added in the meta environment
                            dns_fallback - The comma separated list of DNS servers for the environment
                            dns          - Full URL (including port) of the DNS connection
                            serf_lan     - Full URL (including port) of the Serf connection for consul instance on the LAN
                            server       - Full URL (including port) of the server connection

                        ...

                        <CONSUL_SERVER_NUMBER_N-1>
                            ...

                [NOTE] The following key-value entries are only added in the meta environment
                <ENVIRONMENT_1>
                    consul
                        <CONSUL_SERVER_NUMBER>
                            ...

                ...

                <ENVIRONMENT_N>
                    consul
                        ....

            provisioning

            services
#>

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


    .PARAMETER environment

    The name of the environment for which the key value should be returned.


    .PARAMETER consulLocalAddress

    The URL to the local consul agent.


    .PARAMETER consulServerIndex

    The index of the consul server instance that should be queried.


    .OUTPUTS

    The data center for the given environment.
#>
function Get-ConsulDataCenter
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $environment        = 'staging',

        [ValidateNotNullOrEmpty()]
        [string] $consulLocalAddress = "http://localhost:8500",

        [Parameter(Mandatory = $false)]
        [int] $consulServerIndex     = -1
    )

    Write-Verbose "Get-ConsulDataCenter - environment: $environment"
    Write-Verbose "Get-ConsulDataCenter - consulLocalAddress: $consulLocalAddress"
    Write-Verbose "Get-ConsulDataCenter - consulServerIndex: $consulServerIndex"

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $PSBoundParameters.ContainsKey('Debug');
            ErrorAction = "Stop"
        }

    if ($consulServerIndex -lt 0)
    {
        $numberOfServers = Get-NumberOfConsulServersInEnvironment `
            -environment $environment `
            -consulLocalAddress $consulLocalAddress `
            @commonParameterSwitches
        $serverToGet = 1..$numberOfServers | Get-Random
    }

    $kvSubUrl = Get-UrlRelativePathForEnvironmentKeyValuesForConsul `
        -environment $environment `
        -serverIndex $serverToGet `
        @commonParameterSwitches

    $consulDataCenter = Get-ConsulKeyValue `
        -environment $environment `
        -keyPath "$($kvSubUrl)/datacenter" `
        @commonParameterSwitches

    return $consulDataCenter
}

<#
    .SYNOPSIS

    Gets the domain that the consul DNS nodes listen to.


    .DESCRIPTION

    The Get-ConsulDomain function gets domain that the consul DNS nodes listen to, e.g. .consul.


    .PARAMETER environment

    The name of the environment for which the key value should be returned.


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
        [string] $environment        = 'staging',

        [ValidateNotNullOrEmpty()]
        [string] $consulLocalAddress = "http://localhost:8500",

        [Parameter(Mandatory = $false)]
        [int] $consulServerIndex     = -1
    )

    Write-Verbose "Get-ConsulDomain - environment: $environment"
    Write-Verbose "Get-ConsulDomain - consulLocalAddress: $consulLocalAddress"
    Write-Verbose "Get-ConsulDomain - consulServerIndex: $consulServerIndex"

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $PSBoundParameters.ContainsKey('Debug');
            ErrorAction = "Stop"
        }

    if ($consulServerIndex -lt 0)
    {
        $numberOfServers = Get-NumberOfConsulServersInEnvironment `
            -environment $environment `
            -consulLocalAddress $consulLocalAddress `
            @commonParameterSwitches
        $consulServerIndex = 1..$numberOfServers | Get-Random
    }

    $kvSubUrl = Get-UrlRelativePathForEnvironmentKeyValuesForConsul `
        -environment $environment `
        -serverIndex $consulServerIndex `
        @commonParameterSwitches

    $consulHttpUri = "$($consulLocalAddress)/$($kvSubUrl)/http"
    $consulHttpResponse = Invoke-WebRequest -Uri $consulHttpUri -UseBasicParsing -UseDefaultCredentials @commonParameterSwitches
    $json = ConvertFrom-Json -InputObject $consulHttpResponse @commonParameterSwitches
    $consulHttp = ConvertFrom-ConsulEncodedValue -encodedValue $json.Value @commonParameterSwitches

    $nodeSelfUri = "http://$($consulHttp)/v1/agent/self"
    $response = Invoke-WebRequest -Uri $nodeSelfUri -UseBasicParsing -UseDefaultCredentials @commonParameterSwitches
    $json = ConvertFrom-Json -InputObject $response @commonParameterSwitches

    return $json.Domain
}

<#
    .SYNOPSIS

    Gets the value for a given key from the key-value storage on a given data center.


    .DESCRIPTION

    The Get-ConsulKeyValue function gets the value for a given key from the key-value storage on a given data center.


    .PARAMETER environment

    The name of the environment for which the key value should be returned.


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
        [string] $environment = 'staging',

        [ValidateNotNullOrEmpty()]
        [string] $consulLocalAddress = "http://localhost:8500",

        [ValidateNotNullOrEmpty()]
        [string] $keyPath
    )

    Write-Verbose "Get-ConsulKeyValue - environment: $environment"
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

    $localEnvironment = Get-EnvironmentForLocalNode -consulLocalAddress $consulLocalAddress @commonParameterSwitches
    if ($environment -eq $localEnvironment)
    {
        $keyUri = "$($consulLocalAddress)/v1/kv/$($keyPath)"
    }
    else
    {
        $serverDataCenter = Get-ConsulDataCenter `
            -environment $environment `
            -consulLocalAddress $consulLocalAddress `
            @commonParameterSwitches
        $metaServer = Get-ConsulMetaServer -consulLocalAddress $consulLocalAddress

        # Always call out to the meta server because we assume that the meta server is the only one that will be publicly
        # available
        $keyUri = "$($metaServer.Http)/v1/kv/$($keyPath)?dc=$([System.Web.HttpUtility]::UrlEncode($serverDataCenter))"
    }

    $keyResponse = Invoke-WebRequest -Uri $keyUri -UseBasicParsing -UseDefaultCredentials @commonParameterSwitches
    $json = ConvertFrom-Json -InputObject $keyResponse @commonParameterSwitches
    $value = ConvertFrom-ConsulEncodedValue -encodedValue $json.Value @commonParameterSwitches

    return $value
}

<#
    .SYNOPSIS

    Gets the URL of the consul meta server.


    .DESCRIPTION

    The Get-ConsulMetaServer function gets the URL of the consul meta server.


    .PARAMETER consulLocalAddress

    The URL to the local consul agent.


    .OUTPUTS

    A custom object containing the information about the consul meta server. The object contains
    the following properties:

        DataCenter
        Http
#>
function Get-ConsulMetaServer
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $consulLocalAddress = "http://localhost:8500"
    )

    Write-Verbose "Get-ConsulMetaServer - consulLocalAddress: $consulLocalAddress"

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $PSBoundParameters.ContainsKey('Debug');
            ErrorAction = "Stop"
        }

    # Go to the local consul node and get the address and the data center for the meta server
    $environment = 'meta'
    $numberOfServers = Get-NumberOfConsulServersInEnvironment `
        -environment $environment `
        -consulLocalAddress $consulLocalAddress `
        @commonParameterSwitches
    $serverToGet = 1..$numberOfServers | Get-Random
    $kvSubUrl = Get-UrlRelativePathForEnvironmentKeyValuesForConsul `
        -environment $environment `
        -serverIndex $serverToGet `
        @commonParameterSwitches

    # Get these values from the local consul instance because the current function is used by other functions in order to
    # locate the meta server.
    $consulHttpUri = "$($consulLocalAddress)/$($kvSubUrl)/http"
    $consulHttpResponse = Invoke-WebRequest -Uri $consulHttpUri -UseBasicParsing -UseDefaultCredentials @commonParameterSwitches
    $json = ConvertFrom-Json -InputObject $consulHttpResponse @commonParameterSwitches
    $consulHttp = ConvertFrom-ConsulEncodedValue -encodedValue $json.Value @commonParameterSwitches

    $consulDataCenterUri = "$($consulLocalAddress)/$($kvSubUrl)/datacenter"
    $consulDataCenterResponse = Invoke-WebRequest -Uri $consulDataCenterUri -UseBasicParsing -UseDefaultCredentials @commonParameterSwitches
    $json = ConvertFrom-Json -InputObject $consulDataCenterResponse @commonParameterSwitches
    $consulDataCenter = ConvertFrom-ConsulEncodedValue -encodedValue $json.Value @commonParameterSwitches

    $result = New-Object psobject
    Add-Member -InputObject $result -MemberType NoteProperty -Name DataCenter -Value $consulDataCenter
    Add-Member -InputObject $result -MemberType NoteProperty -Name Http -Value $consulHttp

    return $result
}

<#
    .SYNOPSIS

    Gets the connection information for a given environment.


    .DESCRIPTION

    The Get-ConsulTargetEnvironmentData function gets the connection information for a given environment.


    .PARAMETER environment

    The name of the environment for which the environment information should be returned.


    .PARAMETER consulLocalAddress

    The URL to the local consul agent.


    .OUTPUTS

    A custom object containing the information about the consul cluser for the given environment. The object
    contains the following properties:

        DataCenter
        Http
        Dns
        SerfLan
        SerfWan
        Server
#>
function Get-ConsulTargetEnvironmentData
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $environment = 'staging',

        [ValidateNotNullOrEmpty()]
        [string] $consulLocalAddress = "http://localhost:8500"
    )

    Write-Verbose "Get-ConsulTargetEnvironmentData - environment: $environment"
    Write-Verbose "Get-ConsulTargetEnvironmentData - consulLocalAddress: $consulLocalAddress"

    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $PSBoundParameters.ContainsKey('Debug');
            ErrorAction = "Stop"
        }

    $numberOfServers = Get-NumberOfConsulServersInEnvironment `
        -environment $environment `
        -consulLocalAddress $consulLocalAddress `
        @commonParameterSwitches
    $serverToGet = 1..$numberOfServers | Get-Random
    $kvSubUrl = Get-UrlRelativePathForEnvironmentKeyValuesForConsul `
        -environment $environment `
        -serverIndex $serverToGet `
        @commonParameterSwitches

    # Get the domain for the datacenter for our environment (e.g. all DNS names in the production environment end with .myprod)
    $consulDomain = Get-ConsulDomain `
        -environment $environment `
        -consulLocalAddress $consulLocalAddress `
        -consulServerIndex $serverToGet `
        @commonParameterSwitches

    # Get the name of the datacenter for our environment (e.g. the production environment is in the MyCompany-MyLocation01 datacenter)
    $consulDataCenter = Get-ConsulDataCenter `
        -environment $environment `
        -consulLocalAddress $consulLocalAddress `
        -consulServerIndex $serverToGet `
        @commonParameterSwitches

    # Get the http URL
    $consulHttp = Get-ConsulKeyValue `
        -environment $environment `
        -keyPath "$($kvSubUrl)/http" `
        @commonParameterSwitches

    # Get the DNS URL
    $consulDns = Get-ConsulKeyValue `
        -environment $environment `
        -keyPath "$($kvSubUrl)/dns" `
        @commonParameterSwitches

    # Get the serf_lan URL
    $consulSerfLan = Get-ConsulKeyValue `
        -environment $environment `
        -keyPath "$($kvSubUrl)/serf_lan" `
        @commonParameterSwitches

    # Get the serf_wan URL
    $consulSerfWan = Get-ConsulKeyValue `
        -environment $environment `
        -keyPath "$($kvSubUrl)/serf_wan" `
        @commonParameterSwitches

    # Get the server URL
    $consulServer = Get-ConsulKeyValue `
        -environment $environment `
        -keyPath "$($kvSubUrl)/server" `
        @commonParameterSwitches

    $result = New-Object psobject
    Add-Member -InputObject $result -MemberType NoteProperty -Name Domain -Value $consulDomain
    Add-Member -InputObject $result -MemberType NoteProperty -Name DataCenter -Value $consulDataCenter
    Add-Member -InputObject $result -MemberType NoteProperty -Name Http -Value $consulHttp
    Add-Member -InputObject $result -MemberType NoteProperty -Name Dns -Value $consulDns
    Add-Member -InputObject $result -MemberType NoteProperty -Name SerfLan -Value $consulSerfLan
    Add-Member -InputObject $result -MemberType NoteProperty -Name SerfWan -Value $consulSerfWan
    Add-Member -InputObject $result -MemberType NoteProperty -Name Server -Value $consulServer

    return $result
}

<#
    .SYNOPSIS

    Gets the name of the environment that the local node belongs to.


    .DESCRIPTION

    The Get-EnvironmentForLocalNode function gets the name of the environment that the local node belongs to.


    .PARAMETER consulLocalAddress

    The URL to the local consul agent.


    .OUTPUTS

    The name of the environment that the local node belongs to.
#>
function Get-EnvironmentForLocalNode
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $consulLocalAddress = "http://localhost:8500"
    )

    Write-Verbose "Get-EnvironmentForLocalNode - consulLocalAddress: $consulLocalAddress"

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $PSBoundParameters.ContainsKey('Debug');
            ErrorAction = "Stop"
        }

    # Get the DC for the local node
    $serviceUri = "$($consulLocalAddress)/v1/kv/environment/self"
    $serviceResponse = Invoke-WebRequest -Uri $serviceUri -UseBasicParsing -UseDefaultCredentials @commonParameterSwitches
    if ($serviceResponse.StatusCode -ne 200)
    {
        throw "Server did not return information about the local Consul node."
    }

    $json = ConvertFrom-Json -InputObject $serviceResponse @commonParameterSwitches
    $environmentName = ConvertFrom-ConsulEncodedValue -encodedValue $json.Value @commonParameterSwitches
    return $environmentName
}

<#
    .SYNOPSIS

    Gets the DNS recursor address that will be used by consul to resolve DNS queries outside the consul domain.


    .DESCRIPTION

    The Get-DnsFallbackIp function gets the DNS recursor address that will be used by consul to
    resolve DNS queries outside the consul domain.


    .PARAMETER environment

    The name of the environment for which the key value should be returned.


    .PARAMETER consulLocalAddress

    The URL to the local consul agent.


    .OUTPUTS

    The IP or address of the DNS server that will be used to by consul to resolve DNS queries from outside the consul domain.
#>
function Get-DnsFallbackIp
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $environment = 'staging',

        [ValidateNotNullOrEmpty()]
        [string] $consulLocalAddress = "http://localhost:8500"
    )

    Write-Verbose "Get-DnsFallbackIp - environment: $environment"
    Write-Verbose "Get-DnsFallbackIp - consulLocalAddress: $consulLocalAddress"

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $PSBoundParameters.ContainsKey('Debug');
            ErrorAction = "Stop"
        }

    $numberOfServers = Get-NumberOfConsulServersInEnvironment `
        -environment $environment `
        -consulLocalAddress $consulLocalAddress `
        @commonParameterSwitches
    $serverToGet = 0..$($numberOfServers - 1) | Get-Random
    $kvSubUrl = Get-UrlRelativePathForEnvironmentKeyValuesForConsul `
        -environment $environment `
        -serverIndex $serverToGet `
        @commonParameterSwitches

    # Get the http URL
    $dnsFallback = Get-ConsulKeyValue `
        -environment $environment `
        -keyPath "$($kvSubUrl)/dns_fallback" `
        @commonParameterSwitches

    return $dnsFallback
}

<#
    .SYNOPSIS

    Gets the number of Consul server instances in the given environment.


    .DESCRIPTION

    The Get-NumberOfConsulServersInEnvironment function gets the number of Consul server instances in the given environment.


    .PARAMETER environment

    The name of the environment for which the key value should be returned.


    .PARAMETER consulLocalAddress

    The URL to the local Consul agent.


    .OUTPUTS

    The number of Consul server instances in the given environment
#>
function Get-NumberOfConsulServersInEnvironment
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $environment = 'staging',

        [ValidateNotNullOrEmpty()]
        [string] $consulLocalAddress = "http://localhost:8500"
    )

    # Getting values from the local server because the current function is called by functions that try to find
    # the meta environment. If we call out to other functions to get the key-value pairs then we go around in circles
    $environmentSubUrl = Get-UrlRelativePathForEnvironmentKeyValues -environment $environment @commonParameterSwitches
    $consulServerCountUri = "$($consulLocalAddress)/v1/kv/$($environmentSubUrl)/consul/number_of_servers"

    $response = Invoke-WebRequest -Uri $consulServerCountUri -UseBasicParsing -UseDefaultCredentials @commonParameterSwitches
    $json = ConvertFrom-Json -InputObject $response @commonParameterSwitches
    $value = ConvertFrom-ConsulEncodedValue -encodedValue $json.Value @commonParameterSwitches

    return [int]$value
}

<#
    .SYNOPSIS

    Gets the IP address of the node providing the given service.


    .DESCRIPTION

    The Get-ResourceNamesForService function gets the IP address of the node providing the given service.


    .PARAMETER environment

    The name of the environment for which the key value should be returned.


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
        [string] $environment = 'staging',

        [ValidateNotNullOrEmpty()]
        [string] $consulLocalAddress = "http://localhost:8500",

        [ValidateNotNullOrEmpty()]
        [string] $service,

        [ValidateNotNull()]
        [string] $tag = ''
    )

    Write-Verbose "Get-ResourceNamesForService - environment: $environment"
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

    $server = Get-ConsulTargetEnvironmentData -environment $environment -consulLocalAddress $consulLocalAddress @commonParameterSwitches
    $metaServer = Get-ConsulMetaServer -consulLocalAddress $consulLocalAddress

    # Always call out to the meta server because we assume that the meta server is the only one that will be publicly
    # available
    $serviceUri = "$($metaServer.Http)/v1/catalog/service/$($service)?dc=$([System.Web.HttpUtility]::UrlEncode($meta.DataCenter))"
    if ($tag -ne '')
    {
        $serviceUri += "&tag=$([System.Web.HttpUtility]::UrlEncode($tag))"
    }

    $serviceResponse = Invoke-WebRequest -Uri $serviceUri -UseBasicParsing -UseDefaultCredentials @commonParameterSwitches
    $json = ConvertFrom-Json -InputObject $serviceResponse @commonParameterSwitches
    $serviceAddress = $json[0].Address

    return $serviceAddress
}

<#
    .SYNOPSIS

    Gets the relative URL used for getting key-value information.


    .DESCRIPTION

    The Get-UrlRelativePathForEnvironmentKeyValues function gets the relative URL used for getting key-value information.


    .PARAMETER environment

    The name of the environment for which the key value should be returned.


    .OUTPUTS

    The relative URL used for getting key-value information.
#>
function Get-UrlRelativePathForEnvironmentKeyValues
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $environment = 'staging'
    )

    Write-Verbose "Get-UrlRelativePathForEnvironmentKeyValues - environment: $environment"

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $PSBoundParameters.ContainsKey('Debug');
            ErrorAction = "Stop"
        }

    $lowerCaseEnvironment = $environment.ToLower()
    return "environment/$([System.Web.HttpUtility]::UrlEncode($lowerCaseEnvironment))"
}

<#
    .SYNOPSIS

    Gets the relative URL used for getting key-value information about the consul service.


    .DESCRIPTION

    The Get-UrlRelativePathForEnvironmentKeyValues function gets the relative URL used for getting key-value information about the consul service.


    .PARAMETER environment

    The name of the environment for which the key value should be returned.


    .PARAMETER serverIndex

    The index of the consul server instance that should be queried.


    .OUTPUTS

    The relative URL used for getting key-value information about the consul service.
#>
function Get-UrlRelativePathForEnvironmentKeyValuesForConsul
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $environment = 'staging',

        [int] $serverIndex = 0
    )

    Write-Verbose "Get-UrlRelativePathForEnvironmentKeyValuesForConsul - environment: $environment"
    Write-Verbose "Get-UrlRelativePathForEnvironmentKeyValuesForConsul - serverIndex: $serverIndex"

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $PSBoundParameters.ContainsKey('Debug');
            ErrorAction = "Stop"
        }

    $environmentSubUrl = Get-UrlRelativePathForEnvironmentKeyValues -environment $environment @commonParameterSwitches
    return "$($environmentSubUrl)/consul/$($serverIndex)"
}

<#
    .SYNOPSIS

    Adds an external service to the given consul environment.


    .DESCRIPTION

    The Set-ConsulExternalService function adds an external service to the given consul environment


    .PARAMETER environment

    The name of the environment to which the external service should be added.


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
        [Parameter(ParameterSetName='ByName')]
        [string] $environment,

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

    switch ($PsCmdlet.ParameterSetName)
    {
        "ByName"
        {
            $server = Get-ConsulTargetEnvironmentData -environment $environment -consulLocalAddress $httpUrl @commonParameterSwitches
            $metaServer = Get-ConsulMetaServer -consulLocalAddress $consulLocalAddress

            # Always call out to the meta server because we assume that the meta server is the only one that will be publicly
            # available
            $url = $metaServer.Http
            $dc = $server.DataCenter
        }
        "ByUrl"
        {
            $url = $httpUrl
            $dc = $dataCenter
        }
    }

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


    .PARAMETER environment

    The name of the environment on which the key value should be set.


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
        [Parameter(ParameterSetName='ByName')]
        [string] $environment,

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

    switch ($PsCmdlet.ParameterSetName)
    {
        "ByName"
        {
            $server = Get-ConsulTargetEnvironmentData -environment $environment -consulLocalAddress $httpUrl @commonParameterSwitches
            $metaServer = Get-ConsulMetaServer -consulLocalAddress $consulLocalAddress

            # Always call out to the meta server because we assume that the meta server is the only one that will be publicly
            # available
            $url = $metaServer.Http
            $dc = $server.DataCenter
        }
        "ByUrl"
        {
            $url = $httpUrl
            $dc = $dataCenter
        }
    }

    $uri = "$($url)/v1/kv/$($keyPath)?dc=$([System.Web.HttpUtility]::UrlEncode($dc))"
    $response = Invoke-WebRequest -Uri $uri -Method Put -Body $value -UseBasicParsing -UseDefaultCredentials @commonParameterSwitches
    if ($response.StatusCode -ne 200)
    {
        throw "Failed to set Key-Value pair [$keyPath] - [$value] on [$dc]"
    }
}

<#
    .SYNOPSIS

    Sets the information about the meta server on a given environment.


    .DESCRIPTION

    The Set-ConsulMetaServer function sets the information about the meta server on a given environment.


    .PARAMETER environment

    The name of the environment on which the meta information should be set.


    .PARAMETER httpUrl

    The URL to one of the consul agents. Defaults to the localhost address.


    .PARAMETER dataCenter

    The name of the data center for which the value should be set.


    .PARAMETER metaDataCenter

    The name of the data center that contains the meta servers.


    .PARAMETER metaHttpUrl

    The URL of the entry server of the meta cluster.
#>
function Set-ConsulMetaServer
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [Parameter(ParameterSetName='ByName')]
        [string] $environment,

        [ValidateNotNullOrEmpty()]
        [string] $httpUrl = "http://localhost:8500",

        [ValidateNotNullOrEmpty()]
        [Parameter(ParameterSetName='ByUrl')]
        [string] $dataCenter,

        [ValidateNotNullOrEmpty()]
        [string] $metaDataCenter,

        [ValidateNotNullOrEmpty()]
        [string] $metaHttpUrl
    )

    switch ($PsCmdlet.ParameterSetName)
    {
        "ByName"
        {
            Set-ConsulKeyValue `
                -environment $environment `
                -httpUrl $httpUrl `
                -keyPath 'environment/meta/consul/datacenter' `
                -value $metaDataCenter `
                @commonParameterSwitches

            Set-ConsulKeyValue `
                -environment $environment `
                -httpUrl $httpUrl `
                -keyPath 'environment/meta/consul/http' `
                -value $metaHttpUrl `
                @commonParameterSwitches
        }
        "ByUrl"
        {
            Set-ConsulKeyValue `
                -dataCenter $datacenter `
                -httpUrl $httpUrl `
                -keyPath 'environment/meta/consul/datacenter' `
                -value $metaDataCenter `
                @commonParameterSwitches

            Set-ConsulKeyValue `
                -dataCenter $datacenter `
                -httpUrl $httpUrl `
                -keyPath 'environment/meta/consul/http' `
                -value $metaHttpUrl `
                @commonParameterSwitches
        }
    }
}

<#
    .SYNOPSIS

    Sets the connection information for a given environment as key-value pairs on the meta environment.


    .DESCRIPTION

    The Set-ConsulTargetEnvironmentData function sets the connection information for a given environment
    as key-value pairs on the meta environment.


    .PARAMETER metaDataCenter

    The name of the data center of the meta cluster.


    .PARAMETER metaHttpUrl

    The URL to one of the consul agents in the meta cluster.


    .PARAMETER targetEnvironment

    The environment for which the connection information should be set.


    .PARAMETER dataCenter

    The name of the data center for the environment.


    .PARAMETER httpUrl

    The URL for the HTTP endpoint for the environment.


    .PARAMETER dnsUrl

    The URL for the DNS endpoint for the environment.


    .PARAMETER serfLanUrl

    The URL for the endpoint used to discover other consul agents in the same environment.


    .PARAMETER serfLanUrl

    The URL for the endpoint used to discover other consul agents in different environments.


    .PARAMETER serverUrl

    The URL for the endpoint used to connect to the agent.
#>
function Set-ConsulTargetEnvironmentData
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $metaDataCenter,

        [ValidateNotNullOrEmpty()]
        [string] $metaHttpUrl,

        [ValidateNotNullOrEmpty()]
        [string] $targetEnvironment = 'staging',

        [ValidateNotNullOrEmpty()]
        [string] $dataCenter,

        [ValidateNotNullOrEmpty()]
        [string] $httpUrl,

        [ValidateNotNullOrEmpty()]
        [string] $dnsUrl,

        [ValidateNotNullOrEmpty()]
        [string] $serfLanUrl,

        [ValidateNotNullOrEmpty()]
        [string] $serfWanUrl,

        [ValidateNotNullOrEmpty()]
        [string] $serverUrl
    )

    $lowerCaseEnvironment = $targetEnvironment.ToLower()

    # Set the name of the data center
    Set-ConsulKeyValue `
        -dataCenter $metaDatacenter `
        -httpUrl $metaHttpUrl `
        -keyPath "environment/$lowerCaseEnvironment/consul/datacenter" `
        -value $dataCenter `
        @commonParameterSwitches

    # Set the http URL
    Set-ConsulKeyValue `
        -dataCenter $metaDatacenter `
        -httpUrl $metaHttpUrl `
        -keyPath "environment/$lowerCaseEnvironment/consul/http" `
        -value $httpUrl `
        @commonParameterSwitches

    # Set the DNS URL
    Set-ConsulKeyValue `
        -dataCenter $metaDatacenter `
        -httpUrl $metaHttpUrl `
        -keyPath "environment/$lowerCaseEnvironment/consul/dns" `
        -value $dnsUrl `
        @commonParameterSwitches

    # Set the serf_lan URL
    Set-ConsulKeyValue `
        -dataCenter $metaDatacenter `
        -httpUrl $metaHttpUrl `
        -keyPath "environment/$lowerCaseEnvironment/consul/serf_lan" `
        -value $serfLanUrl `
        @commonParameterSwitches

    # Set the serf_wan URL
    Set-ConsulKeyValue `
        -dataCenter $metaDatacenter `
        -httpUrl $metaHttpUrl `
        -keyPath "environment/$lowerCaseEnvironment/consul/serf_wan" `
        -value $serfWanUrl `
        @commonParameterSwitches

    # Set the server URL
    Set-ConsulKeyValue `
        -dataCenter $metaDatacenter `
        -httpUrl $metaHttpUrl `
        -keyPath "environment/$lowerCaseEnvironment/consul/server" `
        -value $serverUrl `
        @commonParameterSwitches
}

<#
    .SYNOPSIS

    Sets the IP address of the DNS fallback server.


    .DESCRIPTION

    The Set-DnsFallbackIP function sets the IP address of the DNS fallback server.


    .PARAMETER environment

    The name of the environment on which the meta information should be set.


    .PARAMETER httpUrl

    The URL to one of the consul agents. Defaults to the localhost address.


    .PARAMETER dataCenter

    The name of the data center for which the value should be set.


    .PARAMETER targetEnvironment

    The environment for which the DNS fallback IP should be set.


    .PARAMETER dnsRecursorIP

    The IP address of the DNS server.
#>
function Set-DnsFallbackIp
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [Parameter(ParameterSetName='ByName')]
        [string] $environment,

        [ValidateNotNullOrEmpty()]
        [string] $httpUrl = "http://localhost:8500",

        [ValidateNotNullOrEmpty()]
        [Parameter(ParameterSetName='ByUrl')]
        [string] $dataCenter,

        [ValidateNotNullOrEmpty()]
        [string] $targetEnvironment,

        [ValidateNotNullOrEmpty()]
        [string] $dnsRecursorIP
    )

    $lowerCaseEnvironment = $targetEnvironment.ToLower()
    switch ($PsCmdlet.ParameterSetName)
    {
        "ByName"
        {
            Set-ConsulKeyValue `
                -environment $environment `
                -httpUrl $httpUrl `
                -keyPath "environment/$lowerCaseEnvironment/consul/dns_fallback" `
                -value $dnsRecursorIP `
                @commonParameterSwitches
        }
        "ByUrl"
        {
            Set-ConsulKeyValue `
                -dataCenter $dataCenter `
                -httpUrl $httpUrl `
                -keyPath "environment/$lowerCaseEnvironment/consul/dns_fallback" `
                -value $dnsRecursorIP `
                @commonParameterSwitches
        }
    }
}