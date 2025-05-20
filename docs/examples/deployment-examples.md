# Doomsday Deployment Examples

This document provides examples of different Doomsday deployment scenarios using the Doomsday Genesis Kit.

## Table of Contents

- [Basic Deployment](#basic-deployment)
- [OCFP Reference Architecture](#ocfp-reference-architecture)
- [Multi-Backend Configuration](#multi-backend-configuration)
- [IaaS-Specific Examples](#iaas-specific-examples)
  - [OpenStack](#openstack)
  - [STACKIT](#stackit)
  - [vSphere](#vsphere)
  - [GCP](#gcp)
- [Feature Combinations](#feature-combinations)
  - [TLS with Load Balancer](#tls-with-load-balancer)
  - [Custom Vault Paths](#custom-vault-paths)

## Basic Deployment

A minimal Doomsday deployment with essential features:

```yaml
---
# basic-deployment.yml

# Network definition
networks:
- name: default
  static: [10.0.0.10]

# Required parameters
params:
  ip: 10.0.0.10
  network: default
  
  # Optional VM customization
  vm_type: default
  stemcell_os: ubuntu-jammy
  
# Enable basic features
features:
- tls       # Enable HTTPS
- userpass  # Enable authentication
```

This configuration will:
- Deploy Doomsday on a single VM at IP 10.0.0.10
- Configure HTTPS access
- Enable username/password authentication
- Use default VM sizing

## OCFP Reference Architecture

For deploying Doomsday in an Open Cloud Foundry Platform environment:

```yaml
---
# ocfp-deployment.yml

# Network definition
networks:
- name: mgmt-doomsday
  static: [10.0.10.10]

# Required parameters
params:
  ip: 10.0.10.10
  network: mgmt-doomsday
  fqdn: doomsday.mgmt.example.com
  
  # Customize OCFP sizing
  ocfp_env_scale: prod  # Options: dev, prod
  
# Enable OCFP (automatically includes tls, lb, userpass)
features:
- ocfp
```

This configuration will:
- Deploy Doomsday according to the OCFP reference architecture
- Configure a load balancer with the specified FQDN
- Automatically configure to monitor certificates in:
  - All BOSH directors discovered
  - Vault paths
  - FQDNs from Terraform outputs
- Use production-sized VMs and disks

## Multi-Backend Configuration

For deploying Doomsday with multiple certificate source backends:

```yaml
---
# multi-backend.yml

# Network definition
networks:
- name: default
  static: [10.0.0.10]

# Required parameters
params:
  ip: 10.0.0.10
  
  # Increase resources for multiple backends
  vm_type: large
  disk_size: 40960  # 40GB
  
# Enable features
features:
- tls
- userpass
- lb
```

After deployment, you would configure additional backends using:
- The Doomsday web interface
- Custom ops files for your environment

## IaaS-Specific Examples

### OpenStack

```yaml
---
# openstack-deployment.yml

# Network definition
networks:
- name: doomsday
  static: [10.11.12.10]

# Required parameters
params:
  ip: 10.11.12.10
  
  # OpenStack-specific recommendations
  vm_type: doomsday
  stemcell_os: ubuntu-jammy
  
# Enable features
features:
- tls
- userpass
- lb
```

This should be paired with an appropriate OpenStack cloud config.

### STACKIT

```yaml
---
# stackit-deployment.yml

# Network definition
networks:
- name: doomsday
  static: [10.11.12.15]

# Required parameters
params:
  ip: 10.11.12.15
  
  # STACKIT-specific recommendations
  vm_type: doomsday
  stemcell_os: ubuntu-jammy
  
# Enable features
features:
- tls
- userpass
- lb
```

This should be paired with a STACKIT cloud config that addresses the 1:1 network-to-subnet relationship.

### vSphere

```yaml
---
# vsphere-deployment.yml

# Network definition
networks:
- name: doomsday
  static: [10.20.30.10]

# Required parameters
params:
  ip: 10.20.30.10
  
  # vSphere-specific recommendations
  vm_type: doomsday
  stemcell_os: ubuntu-jammy
  
# Enable features
features:
- tls
- userpass
- lb
```

This should be paired with a vSphere cloud config with appropriate VM and disk types.

### GCP

```yaml
---
# gcp-deployment.yml

# Network definition
networks:
- name: doomsday
  static: [10.0.1.10]

# Required parameters
params:
  ip: 10.0.1.10
  
  # GCP-specific recommendations
  vm_type: doomsday
  stemcell_os: ubuntu-jammy
  
# Enable features
features:
- tls
- userpass
- lb
```

This should be paired with a GCP cloud config with appropriate network and VM configurations.

## Feature Combinations

### TLS with Load Balancer

For exposing Doomsday behind a load balancer with HTTPS:

```yaml
---
# tls-with-lb.yml

# Network definition
networks:
- name: default
  static: [10.0.0.10]

# Required parameters
params:
  ip: 10.0.0.10
  fqdn: doomsday.example.com
  
  # Load balancer configuration
  lb_vm_ext_name: doomsday-lb  # VM extension defined in cloud config
  
# Enable TLS and load balancer features
features:
- tls
- lb
- userpass
```

This configuration will:
- Deploy Doomsday with HTTPS
- Configure it to work behind a load balancer
- Set up certificates for the specified FQDN

### Custom Vault Paths

For monitoring certificates in custom Vault paths:

```yaml
---
# custom-vault-paths.yml

# Network definition
networks:
- name: default
  static: [10.0.0.10]

# Required parameters
params:
  ip: 10.0.0.10
  
# Enable features
features:
- tls
- userpass
- sharded-vault-paths  # Enable custom vault paths
```

After deployment, configure the Vault paths in the Doomsday Vault environments at `/doomsday` in Vault. For example:

```
# In Vault
secret/my-env/doomsday/vault/prefixes:env1: secret/env1
secret/my-env/doomsday/vault/prefixes:env2: secret/env2
```

This will configure Doomsday to scan:
- `secret/env1/*` for certificates for the `env1` environment
- `secret/env2/*` for certificates for the `env2` environment

## Combining Examples

You can combine aspects of these examples to create the specific deployment you need. For instance, an OCFP deployment on STACKIT with custom Vault paths would combine elements from the OCFP, STACKIT, and Custom Vault Paths examples.