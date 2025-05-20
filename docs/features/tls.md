# TLS Feature

The `tls` feature enables HTTPS support for the Doomsday web interface, providing secure, encrypted access to the service.

## Overview

When enabled, the `tls` feature:

1. Configures Doomsday to listen on port 443 (HTTPS)
2. Sets up TLS certificates to secure communications
3. Stores certificates in Vault for easy management
4. Exports the certificates in the Genesis exodus data for use by other systems

## Configuration

### Enabling the Feature

Add `tls` to your environment's feature list:

```yaml
---
features:
- tls
```

This feature is automatically enabled when using the `ocfp` feature.

### Parameters

The following parameters affect TLS configuration:

- `cert_dns_name`: The DNS name to use for the TLS certificate. Defaults to `doomsday.<network>.bosh`.
- `ca_validity_period`: How long the CA certificate should be valid. Defaults to `10y`.
- `cert_validity_period`: How long the server certificate should be valid. Defaults to `10y`.

## Behavior

When the `tls` feature is enabled:

1. **Certificate Generation**
   - Genesis creates a CA certificate and server certificate during deployment
   - Certificates are stored in Vault under the environment's secrets mount

2. **Server Configuration**
   - Doomsday is configured to listen on port 443
   - TLS certificates are provided to the Doomsday server
   - HTTP traffic is automatically redirected to HTTPS

3. **Certificate Rotation**
   - Certificates can be rotated using `genesis rotate-secrets <env>`
   - After rotation, a redeployment is needed to apply the new certificates

## Implementation Details

The TLS feature is implemented through the `manifests/addons/tls.yml` file, which:

1. Retrieves certificates from Vault
2. Configures Doomsday for TLS
3. Adds the certificates to the deployment's exodus data

The certificate configuration is defined in `kit.yml`:

```yaml
certificates:
  tls:
    ssl:
      ca:
        valid_for: ${params.ca_validity_period}
      server:
        valid_for: ${params.cert_validity_period}
        names:
          - ${params.cert_dns_name}
```

## Accessing Doomsday with TLS

With TLS enabled, access Doomsday via:

- Direct IP access: `https://<ip>`
- FQDN access (if configured): `https://<fqdn>`

Your browser will validate the TLS certificate. If you're using the default certificate with a `.bosh` domain, you may need to accept the certificate warning in your browser or add the CA certificate to your trusted authorities.

## Example

Here's an example of an environment file using the TLS feature:

```yaml
---
# tls-deployment.yml

# Network definition
networks:
- name: default
  static: [10.0.0.10]

# Required parameters
params:
  ip: 10.0.0.10
  
  # Custom TLS configuration
  cert_dns_name: doomsday.example.com
  ca_validity_period: 5y
  cert_validity_period: 1y
  
# Enable TLS
features:
- tls
```

## Considerations

1. **Certificate Validity**
   - Consider the appropriate validity period for your certificates
   - Shorter validity periods enhance security but require more frequent rotation

2. **DNS Configuration**
   - For external access, ensure DNS is properly configured for the certificate name
   - For internal use, add the certificate name to your hosts file or internal DNS

3. **Certificate Trust**
   - For production use, consider using certificates from a trusted CA
   - For internal use, distribute the CA certificate to clients

4. **Certificate Monitoring**
   - Doomsday can monitor its own TLS certificate
   - Configure alerting to notify before the certificate expires