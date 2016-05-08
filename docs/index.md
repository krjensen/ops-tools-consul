# Ops-Tools-Consul
Contains scripts and tools to interact with one or more consul instances as created by the ops-resource-core scripts

## Assumptions
It is assumed that there is at least one `environment` that describes the other environment. This environment is referered to
as the meta environment. The meta environment may or may not have any services attached to it.

## Key-Value operations
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