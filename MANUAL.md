# Doomsday Genesis Kit Manual

The **Doomsday Genesis Kit** deploys and manages the Doomsday certificate monitoring service using the [Doomsday BOSH Release](https://github.com/doomsday-project/doomsday-boshrelease).

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Parameters](#parameters)
- [Cloud Configuration](#cloud-configuration)
- [Addons](#addons)
- [Deployment Examples](#deployment-examples)
- [Accessing Doomsday](#accessing-doomsday)
- [Upgrading](#upgrading)
- [Troubleshooting](#troubleshooting)

## Overview

### What is Doomsday?

Doomsday is a certificate monitoring system that tracks X.509 certificates across various platforms and alerts when certificates are approaching expiration. It helps prevent outages due to expired certificates by providing a centralized view of certificate health.

### General Usage Guidelines

This Doomsday kit assumes that it is being deployed in a Management environment ("Mgmt"). It will:

- Scan the deployments of the BOSH director for certificates
- Target all BOSH directors it discovers to scan their CredhHub for certificates
- Scan Vault paths for certificates
- If using the `ocfp` feature, scan FQDNs defined in Terraform outputs

## Features

### Available Features

#### Core Features

- **ocfp** - Open Cloud Foundry Platform - Deploys Doomsday according to the OCFP reference architecture. Automatically enables `tls`, `lb`, and `userpass` features. When enabled, Doomsday will look up:
  - The BOSH director that deploys it to find other BOSH directors
  - Terraform outputs in Vault at paths `mgmt/fqdns` and `ocf/fqdns` to monitor certificates
  - The Vault path certificates defined in the environment

#### Authentication Features

- **userpass** - Enables username/password authentication for accessing the Doomsday UI. Creates credentials in Vault for administrator access.

#### Network Features

- **tls** - Enables HTTPS for the Doomsday UI using TLS certificates. Certificates are stored in Vault.
- **lb** - Configures Doomsday instances for use behind a load balancer. Adds necessary VM extensions.

#### Storage Features

- **sharded-vault-paths** - (Not recommended) Allows configuration of custom Vault path prefixes for certificate scanning. If enabled, Doomsday will read configured path prefixes from the vault environment path at `/doomsday`. These prefixes tell the Doomsday vault configuration which paths to scan for certificates.

### Feature Combinations

The `ocfp` feature automatically enables:
- `tls` (HTTPS access)
- `lb` (load balancer support)
- `userpass` (authentication)

## Parameters

### Required Parameters

- `ip` - The static IP address to deploy the Doomsday service to. This IP must exist within the static range of the `network`.

- `network` - The name of the `network` (per cloud-config) where the Doomsday Service will be deployed. Defaults to `doomsday`.

### Optional Parameters

#### Networking Parameters

- `fqdn` - (Optional) The FQDN DNS Name of the Load Balancer fronting the Doomsday service.

- `cert_dns_name` - Custom DNS name to use for the TLS certificate. Defaults to `doomsday.<network>.bosh`.

- `lb_vm_ext_name` - The VM extension to use for load balancer configuration. Defaults to `doomsday-lb`.

#### VM and Disk Parameters

- `stemcell_os` - The operating system for the Doomsday VM. Defaults to `ubuntu-jammy`.

- `stemcell_version` - The version of the stemcell to deploy. Defaults to `latest`.

- `vm_type` - The name of the `vm_type` (per cloud-config) for the Doomsday VM. Defaults to `doomsday` or `default`.

- `disk_size` - Size of the persistent disk provided to the Doomsday service. Defaults to `20480` (20G).

- `availability_zones` - The availability zones to deploy to. Defaults to `z1`.

#### Authentication Parameters

- `server_auth_timeout` - Session timeout in minutes for authenticated users. Defaults to 30 minutes.

- `server_auth_refresh` - Whether to refresh authentication sessions. Defaults to `true`.

#### Certificate Parameters

- `ca_validity_period` - How long the CA certificate should be valid. Defaults to `10y`.

- `cert_validity_period` - How long the server certificate should be valid. Defaults to `10y`.

#### OCFP Parameters

- `ocfp_env_scale` - Size of environment for OCFP deployments. Can be `dev` or `prod`. Affects VM and disk sizing. Defaults to `dev`.

## Cloud Configuration

This kit supports multiple IaaS providers for deploying the Doomsday service:

### OpenStack

For OpenStack deployments, the cloud config needs to specify:
- Network with appropriate `net_id` and `security_groups`
- VM types with appropriate `instance_type` and disk settings
- Disk types with appropriate `type` specifications

Example OpenStack cloud config settings:
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

### STACKIT

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

### vSphere

For vSphere deployments, the cloud config needs to specify:
- Network with appropriate `name`
- VM types with CPU, RAM, and disk settings
- Disk types with appropriate `type` specifications

### GCP

For GCP deployments, the cloud config needs to specify:
- Network with appropriate `network_name` and `subnetwork_name`
- VM types with appropriate `machine_type` and disk settings
- Disk types with appropriate `type` specifications

## Addons

### TLS Addon

The `tls` addon provides HTTPS support for the Doomsday UI:

- Configures Doomsday to listen on port 443
- Sets up TLS certificates from Vault
- Exports the certificates for use by other systems

This addon is added automatically when using the `ocfp` feature or explicitly with `tls`.

### Load Balancer Addon

The `lb` addon configures Doomsday for use behind a load balancer:

- Adds the VM extension specified by `lb_vm_ext_name` (defaults to `doomsday-lb`)
- This extension should be defined in your cloud config to apply the necessary IaaS-specific load balancer settings

This addon is added automatically when using the `ocfp` feature or explicitly with `lb`.

### User Authentication Addon

The `userpass` addon provides username/password authentication:

- Configures the Doomsday UI to require authentication
- Creates an admin user with credentials stored in Vault
- Session timeout can be configured with `server_auth_timeout`
- Session refresh can be enabled/disabled with `server_auth_refresh`

This addon is added automatically when using the `ocfp` feature or explicitly with `userpass`.

## Deployment Examples

### Basic Deployment

A minimal Doomsday deployment requires the following:

```yaml
---
# my-environment.yml
networks:
- name: default
  static: [10.0.0.10]

params:
  ip: 10.0.0.10
  
features:
- tls
- userpass
```

### OCFP Deployment

For an OCFP reference architecture deployment:

```yaml
---
# ocfp-env.yml
networks:
- name: mgmt-doomsday
  static: [10.0.10.10]

params:
  ip: 10.0.10.10
  
features:
- ocfp
```

## Accessing Doomsday

Once deployed, you can access the Doomsday UI through:

### Direct IP Access

- If using the `tls` feature: `https://<ip>`
- Without `tls`: `http://<ip>:80`

### FQDN Access

If you configured an `fqdn` parameter and have DNS properly set up:
- If using the `tls` feature: `https://<fqdn>`
- Without `tls`: `http://<fqdn>:80`

### Authentication

If the `userpass` feature is enabled, you'll need to authenticate with:
- Username: `admin`
- Password: Retrieved from Vault at `<prefix>/users/admin:password`

You can get this password using:
```
genesis <env> secrets users/admin:password
```

## Upgrading

To upgrade to a new version of the Doomsday Genesis Kit:

1. Update your deployment repository with the latest kit version:
   ```
   cd my-doomsday-deployments
   genesis update --kit doomsday
   ```

2. Review the release notes for breaking changes

3. Deploy the updated environment:
   ```
   genesis deploy my-environment
   ```

## Troubleshooting

### Common Issues

#### Certificate Renewal

If Doomsday reports certificate expiration for its own certificates:

1. Rotate the certificates:
   ```
   genesis rotate-secrets my-environment
   ```

2. Re-deploy:
   ```
   genesis deploy my-environment
   ```

#### Connectivity Issues

If Doomsday can't connect to a backend:

1. Verify network connectivity
2. Check the credentials used (in Vault)
3. Ensure security groups/firewall rules allow the connections

### Logs

Access the Doomsday logs with:
```
genesis <env> bosh logs doomsday
```