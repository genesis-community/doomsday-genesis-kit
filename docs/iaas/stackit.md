# Deploying Doomsday on STACKIT

This guide provides detailed instructions for deploying the Doomsday service using the Doomsday Genesis Kit on STACKIT infrastructure.

## STACKIT Overview

[STACKIT](https://stackit.de/) is an OpenStack-based IaaS provider with some key differences in its network architecture. Notably, STACKIT has a 1:1 correspondence between networks and subnets, unlike traditional OpenStack which has a single overarching network with multiple subnets.

## Prerequisites

Before deploying to STACKIT, you need:

1. A STACKIT account with appropriate permissions
2. Access to the STACKIT OpenStack API
3. Network connectivity to your STACKIT environment
4. A Genesis deployment environment connected to STACKIT

## Cloud Config Requirements

### Network Configuration

In STACKIT, each subnet corresponds to a separate network. Your cloud config must correctly specify:

- `net_id` for each individual subnet
- Appropriate security groups (typically 'default')

Example network configuration:

```yaml
networks:
- name: doomsday
  type: manual
  subnets:
  - range: 10.11.12.0/24
    gateway: 10.11.12.1
    static: [10.11.12.10-10.11.12.20]
    cloud_properties:
      net_id: d8a67ac1-123a-456b-789c-0123456789ab  # STACKIT subnet ID
      security_groups: ['default']
```

### VM Types

Define VM types with appropriate STACKIT instance types:

```yaml
vm_types:
- name: doomsday
  cloud_properties:
    instance_type: m1.2  # Adjust based on your performance needs
    boot_from_volume: true
    root_disk:
      size: 32  # in gigabytes
```

### Disk Types

Define disk types using STACKIT storage offerings:

```yaml
disk_types:
- name: doomsday
  disk_size: 20480  # 20GB in MB
  cloud_properties:
    type: storage_premium_perf6  # Adjust based on your performance needs
```

## Complete Cloud Config Example

Here's a complete cloud config example for STACKIT:

```yaml
azs:
- name: z1
  cloud_properties: {availability_zone: nova}

vm_types:
- name: doomsday
  cloud_properties:
    instance_type: m1.2
    boot_from_volume: true
    root_disk:
      size: 32

disk_types:
- name: doomsday
  disk_size: 20480
  cloud_properties:
    type: storage_premium_perf6

networks:
- name: doomsday
  type: manual
  subnets:
  - range: 10.11.12.0/24
    gateway: 10.11.12.1
    static: [10.11.12.10-10.11.12.20]
    azs: [z1]
    dns: [8.8.8.8, 8.8.4.4]
    cloud_properties:
      net_id: d8a67ac1-123a-456b-789c-0123456789ab
      security_groups: ['default']

compilation:
  workers: 5
  reuse_compilation_vms: true
  az: z1
  vm_type: doomsday
  network: doomsday
```

## Deployment Example

### Basic STACKIT Deployment

```yaml
---
# stackit-environment.yml

# Network definitions - match these with your cloud config
networks:
- name: doomsday
  static: [10.11.12.15]

# Required parameters
params:
  # Static IP within the doomsday network
  ip: 10.11.12.15
  
  # Optionally specify the network if not using 'doomsday'
  network: doomsday
  
  # FQDN if using a load balancer
  fqdn: doomsday.example.com
  
  # VM and stemcell configuration
  vm_type: doomsday
  stemcell_os: ubuntu-jammy
  
  # Disk configuration
  disk_size: 20480  # 20GB in MB

# Enable features
features:
- tls
- lb
- userpass
```

### OCFP Architecture Deployment on STACKIT

```yaml
---
# stackit-ocfp-environment.yml

# Network definitions
networks:
- name: mgmt-doomsday
  static: [10.11.12.15]

# Required parameters
params:
  # Static IP within the network
  ip: 10.11.12.15
  
  # FQDN for load balancer access
  fqdn: doomsday.mgmt.example.com
  
  # OCFP environment size (dev or prod)
  ocfp_env_scale: dev

# Enable OCFP feature (automatically includes tls, lb, userpass)
features:
- ocfp
```

## STACKIT-Specific Considerations

### Network Architecture

Because STACKIT uses a 1:1 mapping between networks and subnets:

1. Each subnet must be correctly identified in your cloud config
2. Security groups must be properly configured for each subnet
3. When referencing networks, always ensure you're using the correct subnet ID

### Resource Allocation

STACKIT offers various instance types. Choose based on your Doomsday workload:

- For dev/test: `m1.2` (2 vCPU, 4GB RAM)
- For production: `m1.3` (4 vCPU, 8GB RAM) or larger

### Storage Performance

STACKIT offers several storage tiers:

- `storage_premium_perf6`: High-performance SSD storage
- `storage_premium_perf4`: Balanced SSD storage
- `storage_standard`: Standard storage for non-critical workloads

For Doomsday, we recommend `storage_premium_perf6` for optimal database performance.

## Security Groups

Ensure your security groups permit:

- Inbound traffic on port 443 (HTTPS) for UI access
- Outbound traffic to:
  - Your BOSH directors (typically port 25555)
  - Your Vault server (typically port 8200)
  - Any FQDNs you want to monitor (port 443)

## Troubleshooting STACKIT Deployments

### Network Issues

If you encounter connectivity problems:

1. Verify the subnet ID in your cloud config
2. Check security group rules allow necessary traffic
3. Ensure network connectivity between Doomsday and monitored systems

### VM Creation Failures

If VM creation fails:

1. Verify quota availability in your STACKIT account
2. Check if the requested instance type is available
3. Verify boot disk size is within allowed limits

### Performance Issues

If Doomsday performance is suboptimal:

1. Increase VM size (use a larger instance type)
2. Upgrade to a higher-performance storage tier
3. Optimize the number of backends and polling frequency

## References

- [STACKIT Documentation](https://docs.stackit.de/)
- [BOSH OpenStack CPI Documentation](https://bosh.io/docs/openstack-cpi/)
- [Doomsday BOSH Release](https://github.com/doomsday-project/doomsday-boshrelease)