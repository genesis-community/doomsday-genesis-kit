# Load Balancer (LB) Feature

The `lb` feature configures Doomsday for use behind a load balancer, providing high availability and easier external access.

## Overview

When enabled, the `lb` feature:

1. Adds VM extensions to the Doomsday VM for load balancer integration
2. Allows Doomsday to be accessed via a load balancer
3. Works with the cloud config to apply IaaS-specific load balancer settings

## Configuration

### Enabling the Feature

Add `lb` to your environment's feature list:

```yaml
---
features:
- lb
```

This feature is automatically enabled when using the `ocfp` feature.

### Parameters

The following parameters affect load balancer configuration:

- `lb_vm_ext_name`: The name of the VM extension to use for load balancer configuration. Defaults to `doomsday-lb`.
- `fqdn`: The FQDN (Fully Qualified Domain Name) for accessing Doomsday through the load balancer.

## Behavior

When the `lb` feature is enabled:

1. **VM Extension**
   - Adds the VM extension specified by `lb_vm_ext_name` to the Doomsday VM
   - The extension should be defined in your cloud config with IaaS-specific settings

2. **Network Configuration**
   - Configures Doomsday to be accessible through the load balancer
   - When combined with `tls`, ensures secure access through the load balancer

## Implementation Details

The load balancer feature is implemented through the `manifests/addons/lb.yml` file, which:

1. Adds the specified VM extension to the Doomsday VM
2. Applies any necessary configuration for load balancer compatibility

The implementation is minimal because most of the load balancer configuration happens at the cloud config level.

## Cloud Config Requirements

For the `lb` feature to work properly, your cloud config must define the VM extension specified by `lb_vm_ext_name`. The exact configuration depends on your IaaS provider:

### OpenStack/STACKIT Example

```yaml
vm_extensions:
- name: doomsday-lb
  cloud_properties:
    security_groups:
    - default
    - lb
```

### vSphere Example

```yaml
vm_extensions:
- name: doomsday-lb
  cloud_properties:
    nsxt:
      lb:
        server_pools:
        - name: doomsday-pool
          port: 443
```

### GCP Example

```yaml
vm_extensions:
- name: doomsday-lb
  cloud_properties:
    target_pool: doomsday-pool
```

## Example

Here's an example of an environment file using the load balancer feature:

```yaml
---
# lb-deployment.yml

# Network definition
networks:
- name: default
  static: [10.0.0.10]

# Required parameters
params:
  ip: 10.0.0.10
  fqdn: doomsday.example.com
  
  # Custom load balancer configuration
  lb_vm_ext_name: custom-doomsday-lb
  
# Enable load balancer (and TLS for secure access)
features:
- lb
- tls
```

## Considerations

1. **DNS Configuration**
   - Ensure DNS is configured to point the `fqdn` to your load balancer
   - For internal use, add the FQDN to your internal DNS

2. **Health Checks**
   - Configure appropriate health checks on your load balancer
   - For TLS-enabled deployments, ensure health checks use HTTPS

3. **Security Groups**
   - Ensure security groups allow traffic from the load balancer to the Doomsday VM
   - Configure security groups to restrict direct access if desired

4. **TLS Termination**
   - Decide whether TLS termination happens at the load balancer or at Doomsday
   - If terminating at the load balancer, configure it to use the Doomsday certificate