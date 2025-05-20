# Doomsday Installation Guide

This guide provides step-by-step instructions for deploying the Doomsday service using the Doomsday Genesis Kit.

## Prerequisites

Before proceeding, ensure you have met all the [prerequisites](prerequisites.md) for deploying Doomsday.

## Step 1: Create a Deployment Repository

First, create a Genesis deployment repository for Doomsday:

```bash
# Create a doomsday-deployments repo using the latest version of the doomsday kit
genesis init --kit doomsday

# Or specify a specific version
genesis init --kit doomsday/1.0.0

# Or use a custom name for the repository
genesis init --kit doomsday -d my-doomsday-configs
```

This will create a new Git repository with the basic structure needed for deploying Doomsday.

## Step 2: Create an Environment File

Create an environment YAML file for your deployment. For example, `my-environment.yml`:

```yaml
---
# my-environment.yml

# Define the networks and static IPs
networks:
- name: doomsday
  static: [10.0.0.10]

# Define required parameters
params:
  ip: 10.0.0.10
  network: doomsday
  
  # Optionally define a FQDN if using a load balancer
  fqdn: doomsday.example.com

# Enable desired features
features:
- tls
- userpass
```

Save this file in your deployment repository.

## Step 3: Configure Cloud Config

Ensure your BOSH director has an appropriate cloud config for your IaaS provider. The cloud config should include:

- Network definition matching the one in your environment file
- VM type for the Doomsday VM
- Disk type for the Doomsday persistent disk

If you're using the `ocfp` feature, cloud config is handled automatically.

## Step 4: Deploy Doomsday

Deploy Doomsday to your environment:

```bash
# Change to your deployment repository
cd doomsday-deployments

# Deploy to your environment
genesis deploy my-environment
```

Genesis will:
1. Generate a BOSH manifest
2. Create or update necessary Vault credentials
3. Deploy Doomsday using BOSH
4. Output information about the deployment

## Step 5: Verify the Deployment

Verify that the deployment was successful:

```bash
# Check the deployment status
genesis my-environment bosh instances --ps

# Get deployment information
genesis my-environment info
```

The `info` command will show:
- IP address or FQDN for accessing Doomsday
- Admin username and password (if using `userpass` feature)
- Other deployment details

## Step 6: Access Doomsday

Access the Doomsday web interface:

### With TLS and UserPass

1. Open a web browser and navigate to:
   ```
   https://<ip-or-fqdn>
   ```

2. Log in with:
   - Username: `admin`
   - Password: Retrieve from Vault using:
     ```
     genesis my-environment secrets users/admin:password
     ```

### Without TLS

If TLS is not enabled, access Doomsday via HTTP on port 80:
```
http://<ip-or-fqdn>
```

## Step 7: Configure Backends (Optional)

If you're not using the `ocfp` feature or need to configure additional backends:

1. Log in to Doomsday
2. Go to the Configuration section
3. Add and configure backends:
   - BOSH/CredhHub backends
   - Vault backends
   - TLS client backends for network endpoints

## Step 8: Test Certificate Monitoring

Verify that Doomsday is correctly monitoring certificates:

1. Browse the Certificates section in the UI
2. Check that certificates from configured backends appear
3. Verify expiry dates are correctly displayed
4. Test alert thresholds by finding a certificate nearing expiration

## Advanced Deployment Scenarios

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
  fqdn: doomsday.mgmt.example.com
  
features:
- ocfp
```

### Load Balanced Deployment

For deploying behind a load balancer:

```yaml
---
# lb-env.yml
networks:
- name: doomsday
  static: [10.0.0.10]

params:
  ip: 10.0.0.10
  fqdn: doomsday.example.com
  lb_vm_ext_name: doomsday-lb
  
features:
- tls
- lb
- userpass
```

Ensure your cloud config has the appropriate VM extension defined.

### Custom Vault Paths

For monitoring certificates in custom Vault paths:

```yaml
---
# custom-vault-env.yml
networks:
- name: doomsday
  static: [10.0.0.10]

params:
  ip: 10.0.0.10
  
features:
- tls
- userpass
- sharded-vault-paths
```

Configure the Vault paths in your Vault server.

## Troubleshooting

### Deployment Failures

If deployment fails:

1. Check BOSH task logs:
   ```
   genesis my-environment bosh task -d doomsday
   ```

2. Verify cloud config matches your environment file:
   ```
   genesis my-environment bosh cloud-config
   ```

3. Check for Vault access issues:
   ```
   genesis my-environment vault info
   ```

### Access Issues

If you can't access the Doomsday UI:

1. Verify the VM is running:
   ```
   genesis my-environment bosh instances
   ```

2. Check network connectivity to the IP or FQDN
3. Verify TLS certificate is valid (if using HTTPS)
4. Check for correct credentials (if using `userpass` feature)

## Next Steps

After successfully deploying Doomsday:

1. [Configure alerts and notifications](../operations/monitoring.md)
2. [Set up regular certificate scanning](../operations/certificate-management.md)
3. [Integrate with other systems](../operations/integration.md)

For more information, refer to the [Doomsday documentation](https://github.com/doomsday-project/doomsday-boshrelease).