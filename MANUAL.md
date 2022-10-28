
# Doomsday Genesis Kit Manual
The **Doomsday Genesis Kit** deploys the Doomsday Service
using the [Doomsday BOSH Release](https://github.com/doomsday-project/doomsday-boshrelease)

# General Usage Guidelines

TBD

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

# Features

## Features Provided by the Doomsday Genesis Kit

# Available Addons

# Examples

# History
