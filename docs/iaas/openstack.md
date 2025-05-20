# Deploying Doomsday on OpenStack

This guide provides instructions for deploying the Doomsday service using the Doomsday Genesis Kit on OpenStack infrastructure.

## Prerequisites

Before deploying to OpenStack, you need:

1. An OpenStack account with appropriate permissions
2. Access to the OpenStack API
3. Network connectivity to your OpenStack environment
4. A Genesis deployment environment connected to OpenStack

## Cloud Config Requirements

### Network Configuration

In OpenStack, you'll need to define a network for Doomsday. Your cloud config must specify:

- `net_id` for the OpenStack network
- Appropriate security groups (typically 'default')

Example network configuration:

```yaml
networks:
- name: doomsday
  type: manual
  subnets:
  - range: 10.0.0.0/24
    gateway: 10.0.0.1
    static: [10.0.0.10-10.0.0.20]
    cloud_properties:
      net_id: 68bb1b4a-15d1-4058-9af8-4bb5613bbab3  # OpenStack network ID
      security_groups: ['default']
```

### VM Types

Define VM types with appropriate OpenStack instance types:

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

Define disk types using OpenStack storage offerings:

```yaml
disk_types:
- name: doomsday
  disk_size: 20480  # 20GB in MB
  cloud_properties:
    type: storage_premium_perf6  # Adjust based on your performance needs
```

## Complete Cloud Config Example

Here's a complete cloud config example for OpenStack:

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
  - range: 10.0.0.0/24
    gateway: 10.0.0.1
    static: [10.0.0.10-10.0.0.20]
    azs: [z1]
    dns: [8.8.8.8, 8.8.4.4]
    cloud_properties:
      net_id: 68bb1b4a-15d1-4058-9af8-4bb5613bbab3
      security_groups: ['default']

compilation:
  workers: 5
  reuse_compilation_vms: true
  az: z1
  vm_type: doomsday
  network: doomsday
```

## Deployment Example

### Basic OpenStack Deployment

```yaml
---
# openstack-environment.yml

# Network definitions - match these with your cloud config
networks:
- name: doomsday
  static: [10.0.0.15]

# Required parameters
params:
  # Static IP within the doomsday network
  ip: 10.0.0.15
  
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

### OCFP Architecture Deployment on OpenStack

```yaml
---
# openstack-ocfp-environment.yml

# Network definitions
networks:
- name: mgmt-doomsday
  static: [10.0.0.15]

# Required parameters
params:
  # Static IP within the network
  ip: 10.0.0.15
  
  # FQDN for load balancer access
  fqdn: doomsday.mgmt.example.com
  
  # OCFP environment size (dev or prod)
  ocfp_env_scale: dev

# Enable OCFP feature (automatically includes tls, lb, userpass)
features:
- ocfp
```

## OpenStack-Specific Considerations

### Network Architecture

OpenStack has a flexible network architecture:

1. A single network can have multiple subnets
2. Security groups are applied at the network level
3. Floating IPs can be assigned for external access

### Resource Allocation

OpenStack offers various instance types. Choose based on your Doomsday workload:

- For dev/test: `m1.2` (2 vCPU, 4GB RAM)
- For production: `m1.3` (4 vCPU, 8GB RAM) or larger

### Storage Performance

OpenStack offers several storage tiers:

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

## Load Balancer Configuration

If using the `lb` feature, you'll need to configure a load balancer in OpenStack:

1. Create a load balancer in OpenStack
2. Configure a listener for port 443
3. Create a pool and add your Doomsday VM
4. Configure health checks on port 443
5. Assign a floating IP to the load balancer

## Troubleshooting OpenStack Deployments

### Network Issues

If you encounter connectivity problems:

1. Verify the network ID in your cloud config
2. Check security group rules allow necessary traffic
3. Ensure network connectivity between Doomsday and monitored systems

### VM Creation Failures

If VM creation fails:

1. Verify quota availability in your OpenStack account
2. Check if the requested instance type is available
3. Verify boot disk size is within allowed limits

### Performance Issues

If Doomsday performance is suboptimal:

1. Increase VM size (use a larger instance type)
2. Upgrade to a higher-performance storage tier
3. Optimize the number of backends and polling frequency

## References

- [OpenStack Documentation](https://docs.openstack.org/)
- [BOSH OpenStack CPI Documentation](https://bosh.io/docs/openstack-cpi/)
- [Doomsday BOSH Release](https://github.com/doomsday-project/doomsday-boshrelease)