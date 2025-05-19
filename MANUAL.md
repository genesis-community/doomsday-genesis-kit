
# Doomsday Genesis Kit Manual
The **Doomsday Genesis Kit** deploys the Doomsday Service
using the [Doomsday BOSH Release](https://github.com/doomsday-project/doomsday-boshrelease)

# General Usage Guidelines

This Doomsday kit assumes that it is being deployed in a Management environment ("Mgmt")

It will look up the deployments of the BOSH director which deploys it to gather a list
of BOSH directors and automatically configure to target each of them to scan certificates
within their credhub.

If the `ocfp` reference architecutre feature flag is being used it will also look up the 
terraform environment path `mgmt/fqdns` and `ocf/fqdns` and configure to scan their 
ceritifcates for each `fqdns` entry.

It will also look up and scan the vault path certificates, by default using `secret/`.
If the `shareded-vault-paths` feature is being used (not recommended), it will 
read the configured path prefixes to scan from the vault environment path at `/doomsday`.
These prefixes are used when the configuration template is rendered telling the specific
doomsday vault configuration entry what vault path to look in for certificates.

# Base Parameters

- `ip` - The static IP address to deploy the Blacksmith broker
  to.  This must exist within the static range of the `network`.

- `fqdn` - (Optional) The FQDN DNS Name of the Load Balancer
  fronting the Blacksmith broker.

## Sizing and Deployment Parameters

- `network` - The name of the `network` (per cloud-config) where
  the Doomsday Service will be deployed.  Defaults to `doomsday`.

- `stemcell_os` - The operating system you want to deploy the
  Blacksmith service broker itself on.  This defaults to
  `ubuntu-bionic`.

- `stemcell_version` - The version of the stemcell to deploy.
  Defaults to `ubuntu-bionic`

- `vm_type` - The name of the `vm_type` (per cloud-config) that
  will be used to deploy the blacksmith broker VM.  Defaults to
  `doomsday`.

- `disk_size` - How big of a data disk to provide the Doomsday
  service, for persistent storage.  Defaults to `20480` (20G).

## Doomsday Parameters

# Cloud Configuration

This kit supports multiple IaaS providers for deploying the Doomsday service:

## OpenStack

For OpenStack deployments, the cloud config needs to specify:
- Network with appropriate `net_id` and `security_groups`
- VM types with appropriate `instance_type` and disk settings
- Disk types with appropriate `type` specifications

## STACKIT

STACKIT deployments are similar to OpenStack but with a key difference: STACKIT has a 1:1 correspondence of networks to subnets, whereas OpenStack has a single overarching network.

For STACKIT deployments, ensure your cloud config includes:
- Network with appropriate `net_id` and `security_groups` for each subnet
- VM types with appropriate `instance_type` and disk settings
- Disk types with appropriate `type` specifications 

Example STACKIT cloud config settings:
```yaml
networks:
  cloud_properties:
    net_id: <network-id>
    security_groups: ['default']

vm_types:
  cloud_properties:
    instance_type: m1.2
    boot_from_volume: true
    root_disk:
      size: 32

disk_types:
  cloud_properties:
    type: storage_premium_perf6
```

# Features

## Features Provided by the Doomsday Genesis Kit

# Available Addons

# Examples

# History
