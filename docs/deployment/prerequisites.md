# Doomsday Deployment Prerequisites

This document outlines the prerequisites and requirements for deploying the Doomsday service using the Doomsday Genesis Kit.

## Software Requirements

### Genesis

- Genesis version 2.8.7 or later
- The Genesis CLI installed and configured

### BOSH

- A functioning BOSH director
- BOSH CLI installed and configured
- Appropriate BOSH credentials

### Vault

- Access to a Vault server for credential storage
- Appropriate Vault credentials and permissions

## Network Requirements

### IP Allocation

- A static IP address for the Doomsday VM
- The IP must be within the static range of the target network
- If using a load balancer, additional IPs may be required

### Connectivity

Doomsday needs network connectivity to:

1. BOSH directors for certificate scanning
2. Vault server for credential storage and certificate scanning
3. Network endpoints for TLS certificate scanning
4. Client machines for UI access

### DNS (Optional)

If using a custom FQDN:

- DNS resolution for the Doomsday FQDN
- If using a load balancer, DNS should point to the load balancer IP

## IaaS Requirements

### Cloud Config

- Appropriate cloud config for your IaaS provider
- Network definitions matching your infrastructure
- VM and disk types suitable for Doomsday

### IaaS-Specific Requirements

#### OpenStack

- Network with appropriate `net_id`
- Security groups allowing necessary traffic
- Quota for compute, network, and storage resources

#### STACKIT

- Network with appropriate `net_id` (1:1 network-to-subnet relationship)
- Security groups allowing necessary traffic
- Quota for compute, network, and storage resources

#### vSphere

- Network port group available
- Resource pool with sufficient capacity
- Datastore with sufficient space

#### GCP

- Network and subnet configuration
- Firewall rules allowing necessary traffic
- Project with appropriate quotas

## BOSH Requirements

### BOSH Stemcell

- Ubuntu Jammy (default) or other supported stemcell
- Access to the stemcell in your BOSH director

### BOSH Releases

- Access to the Doomsday BOSH release
- The release is configured in the Genesis kit

## Security Requirements

### Vault

- Vault role with permissions to:
  - Read and write secrets in the environment's secrets mount
  - Read certificates from paths being monitored

### BOSH/Credhub

- Credentials with permissions to:
  - Access BOSH directors
  - Read certificates from Credhub

### Network Security

- Firewall rules allowing:
  - Inbound access to Doomsday (port 443 for HTTPS)
  - Outbound access from Doomsday to certificate sources

## Resource Requirements

### Minimum Requirements

- **VM Type**: 1 CPU, 2GB RAM
- **Disk Size**: 20GB
- Suitable for small deployments (< 100 certificates)

### Recommended Requirements

- **VM Type**: 2 CPU, 4GB RAM
- **Disk Size**: 40GB
- Suitable for medium deployments (100-500 certificates)

### Large Deployments

- **VM Type**: 4+ CPU, 8+ GB RAM
- **Disk Size**: 80GB+
- Suitable for large deployments (500+ certificates)

## Pre-Deployment Checklist

Before deploying Doomsday, ensure you have:

1. **Genesis Environment**
   - Genesis installed and configured
   - Access to the Doomsday Genesis Kit

2. **Infrastructure**
   - Cloud config configured for your IaaS
   - Network connectivity between components
   - Required IPs and DNS entries

3. **Security**
   - Vault access configured
   - BOSH/Credhub credentials available
   - TLS certificates (if not using auto-generated)

4. **Target Systems**
   - List of BOSH directors to monitor
   - Vault paths containing certificates
   - Network endpoints with TLS certificates

## Next Steps

Once you have all prerequisites in place, proceed to the [Installation Guide](installation.md) for step-by-step deployment instructions.