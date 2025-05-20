# Doomsday Troubleshooting Guide

This guide provides solutions for common issues encountered when deploying and operating the Doomsday service with the Doomsday Genesis Kit.

## Deployment Issues

### Genesis Deployment Failures

#### Problem: Genesis deployment fails with an error

**Symptoms:**
- `genesis deploy` command fails
- Error message indicates an issue with the deployment

**Solutions:**

1. **Check environment file validity**
   ```bash
   genesis check my-environment
   ```
   Fix any reported issues in your environment file.

2. **Verify Genesis version**
   ```bash
   genesis --version
   ```
   Ensure you have Genesis version 2.8.7 or later.

3. **Update the Genesis kit**
   ```bash
   genesis update --kit doomsday
   ```
   Make sure you have the latest version of the Doomsday Genesis Kit.

### BOSH Deployment Failures

#### Problem: BOSH deployment fails after Genesis generates the manifest

**Symptoms:**
- Genesis processes the deployment but BOSH deployment fails
- BOSH task shows errors

**Solutions:**

1. **Check BOSH task logs**
   ```bash
   genesis my-environment bosh task --debug
   ```
   Look for error messages in the task output.

2. **Verify cloud config compatibility**
   ```bash
   genesis my-environment bosh cloud-config
   ```
   Ensure network names, VM types, and disk types referenced in your environment file exist in the cloud config.

3. **Check stemcell availability**
   ```bash
   genesis my-environment bosh stemcells
   ```
   Ensure the required stemcell is available on your BOSH director.

### Vault Issues

#### Problem: Genesis cannot access Vault credentials

**Symptoms:**
- Errors related to Vault access during deployment
- Error message indicates missing credentials or permission issues

**Solutions:**

1. **Verify Vault connectivity**
   ```bash
   genesis my-environment vault info
   ```
   Ensure Genesis can connect to Vault.

2. **Check Vault permissions**
   ```bash
   genesis my-environment vault paths
   ```
   Ensure the current user has access to the required Vault paths.

3. **Regenerate credentials**
   ```bash
   genesis my-environment rotate-secrets
   ```
   This will regenerate any missing credentials.

## Access Issues

### Web Interface Inaccessible

#### Problem: Cannot access Doomsday web interface

**Symptoms:**
- Browser cannot connect to Doomsday IP or FQDN
- Connection times out or is refused

**Solutions:**

1. **Verify VM is running**
   ```bash
   genesis my-environment bosh instances
   ```
   Ensure the Doomsday VM is running and healthy.

2. **Check network connectivity**
   ```bash
   ping <doomsday-ip>
   ```
   Ensure network connectivity between your client and the Doomsday VM.

3. **Verify security groups/firewall rules**
   Ensure your IaaS security groups allow traffic to port 443 (HTTPS) or 80 (HTTP).

4. **Check load balancer configuration**
   If using a load balancer, verify it is correctly configured and passing health checks.

### TLS Certificate Issues

#### Problem: Browser shows certificate errors

**Symptoms:**
- Browser displays certificate warning
- Certificate appears to be invalid, expired, or for the wrong domain

**Solutions:**

1. **Verify certificate configuration**
   ```bash
   genesis my-environment secrets ssl/server:certificate
   ```
   Check that the certificate is valid and contains the correct domain names.

2. **Regenerate the certificate**
   ```bash
   genesis my-environment rotate-secrets ssl
   genesis my-environment deploy
   ```
   This will create a new certificate and redeploy Doomsday.

3. **Check DNS configuration**
   Ensure the DNS name used in the certificate matches the URL you're accessing.

### Authentication Issues

#### Problem: Cannot log in to Doomsday

**Symptoms:**
- Login attempts fail
- "Invalid username or password" error

**Solutions:**

1. **Verify credentials**
   ```bash
   genesis my-environment secrets users/admin:password
   ```
   Check that you're using the correct password.

2. **Reset the admin password**
   ```bash
   genesis my-environment rotate-secrets users/admin:password
   genesis my-environment deploy
   ```
   This will create a new admin password and redeploy Doomsday.

3. **Check session timeout settings**
   If sessions expire too quickly, adjust the `server_auth_timeout` parameter in your environment file.

## Backend Connection Issues

### BOSH/Credhub Connection Issues

#### Problem: Doomsday cannot connect to BOSH or Credhub

**Symptoms:**
- No certificates from BOSH/Credhub appear in Doomsday
- Error messages in Doomsday logs related to BOSH connection

**Solutions:**

1. **Check BOSH connectivity**
   Verify network connectivity between Doomsday and the BOSH director.

2. **Verify BOSH credentials**
   If using the `ocfp` feature, check that the exodus data from BOSH deployments is correct.

3. **Check TLS verification**
   If BOSH uses self-signed certificates, ensure they are properly trusted.

### Vault Connection Issues

#### Problem: Doomsday cannot connect to Vault

**Symptoms:**
- No certificates from Vault appear in Doomsday
- Error messages in Doomsday logs related to Vault connection

**Solutions:**

1. **Check Vault connectivity**
   Verify network connectivity between Doomsday and the Vault server.

2. **Verify Vault credentials**
   Check that the Vault role and secret IDs are correct.

3. **Verify Vault path configuration**
   If using `sharded-vault-paths`, verify the path prefixes are correctly configured in Vault.

### TLS Endpoint Connection Issues

#### Problem: Doomsday cannot connect to TLS endpoints

**Symptoms:**
- No certificates from TLS endpoints appear in Doomsday
- Error messages in Doomsday logs related to TLS connections

**Solutions:**

1. **Check endpoint connectivity**
   Verify network connectivity between Doomsday and the monitored endpoints.

2. **Verify endpoint configuration**
   Ensure the hostnames and ports are correctly configured.

3. **Check TLS handshake**
   Some servers may require specific TLS versions or cipher suites.

## Performance Issues

### Slow UI Response

#### Problem: Doomsday web interface is slow to respond

**Symptoms:**
- Web interface takes a long time to load
- Operations in the UI are sluggish

**Solutions:**

1. **Check VM resources**
   ```bash
   genesis my-environment bosh ssh doomsday/0 "top -bn1"
   ```
   Verify CPU and memory usage are not excessive.

2. **Increase VM resources**
   Modify your environment file to use a larger VM type:
   ```yaml
   params:
     vm_type: large
   ```

3. **Optimize backend configuration**
   Reduce the number of backends or increase the refresh interval.

### High Resource Usage

#### Problem: Doomsday VM has high CPU or memory usage

**Symptoms:**
- BOSH metrics show high resource utilization
- VM performance is degraded

**Solutions:**

1. **Reduce number of certificates**
   If monitoring thousands of certificates, consider splitting across multiple Doomsday instances.

2. **Adjust refresh intervals**
   Increase the refresh interval for backends to reduce scanning frequency.

3. **Increase VM resources**
   Use a larger VM type with more CPU and memory.

## Log Analysis

### Accessing Logs

To access Doomsday logs:

```bash
# Stream logs
genesis my-environment bosh logs doomsday --follow

# Download logs
genesis my-environment bosh logs doomsday
```

### Common Error Messages

#### "Failed to connect to backend"

This indicates a connectivity issue with a certificate source:

1. Check network connectivity
2. Verify credentials
3. Check that the backend service is running

#### "Certificate parsing error"

This indicates an issue with a certificate format:

1. Check the certificate data in the source
2. Verify the certificate is a valid X.509 certificate

#### "Authentication failed"

This indicates a problem with the credentials used to access a backend:

1. Verify the credentials in Vault
2. Check that the credentials have not expired
3. Ensure the credentials have appropriate permissions

## Advanced Troubleshooting

### BOSH Job Monit Status

Check the status of Doomsday processes:

```bash
genesis my-environment bosh ssh doomsday/0 -c "sudo monit summary"
```

### Database Inspection

Examine the Doomsday database:

```bash
genesis my-environment bosh ssh doomsday/0 -c "ls -la /var/vcap/store/doomsday"
```

### Process Inspection

Check the running Doomsday process:

```bash
genesis my-environment bosh ssh doomsday/0 -c "ps aux | grep doomsday"
```

## Getting Support

If you cannot resolve an issue using this guide:

1. Check the [Doomsday BOSH Release documentation](https://github.com/doomsday-project/doomsday-boshrelease)
2. File an issue on the [Doomsday Genesis Kit repository](https://github.com/genesis-community/doomsday-genesis-kit)
3. Contact your Genesis administrator for additional assistance