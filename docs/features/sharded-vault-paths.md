# Sharded Vault Paths Feature

The `sharded-vault-paths` feature allows configuration of custom Vault path prefixes for certificate scanning. This feature is not generally recommended for most deployments.

## Overview

When enabled, the `sharded-vault-paths` feature:

1. Allows defining custom Vault path prefixes for certificate scanning
2. Reads path prefixes from Vault at deployment time
3. Configures Doomsday to scan specific Vault paths for each environment

## Configuration

### Enabling the Feature

Add `sharded-vault-paths` to your environment's feature list:

```yaml
---
features:
- sharded-vault-paths
```

### Vault Configuration

With this feature enabled, you need to configure the Vault paths in your Vault server:

1. For each environment you want to monitor, create a Vault key at:
   ```
   <secrets_mount>/<env_name_with_slashes>/doomsday/vault/prefixes:<env_name>
   ```

2. Set the value to the Vault path prefix for that environment

For example:
```
# In Vault
secret/my-env/doomsday/vault/prefixes:env1: secret/env1
secret/my-env/doomsday/vault/prefixes:env2: secret/env2
```

## Behavior

When the `sharded-vault-paths` feature is enabled:

1. **Path Resolution**
   - During deployment, the blueprint hook reads the configured path prefixes from Vault
   - If a prefix is not found for an environment, it falls back to `secret`

2. **Backend Configuration**
   - Doomsday is configured with multiple Vault backends, one for each environment
   - Each backend is configured to scan the specified path prefix

3. **Certificate Monitoring**
   - Doomsday monitors certificates found in the specified paths
   - Certificates are grouped by environment in the UI

## Implementation Details

The sharded-vault-paths feature is implemented in `hooks/blueprint.pm`. When enabled:

1. Instead of using the default `secret` prefix, it looks up the prefix for each environment
2. It retrieves the prefix from Vault at:
   ```
   <secrets_mount>/<env_name_with_slashes>/doomsday/vault/prefixes:<env_name>
   ```
3. It passes the prefix to the template rendering function for each environment

## When to Use

This feature is primarily useful in complex environments where:

1. You have many environments with certificates stored in Vault
2. You use different Vault path prefixes for different environments
3. You want to organize certificate monitoring by environment

## Example

Here's an example of using the sharded-vault-paths feature:

```yaml
---
# sharded-vault-paths-deployment.yml

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
- sharded-vault-paths
```

With this configuration, you would also need to set up the path prefixes in Vault:

```
# Vault commands
vault write secret/my-env/doomsday/vault/prefixes:env1 value=secret/env1
vault write secret/my-env/doomsday/vault/prefixes:env2 value=custom/env2/certs
```

## Considerations

1. **Default Behavior**
   - Without this feature, Doomsday uses the `secret` prefix for all environments
   - This is sufficient for most deployments

2. **Management Overhead**
   - This feature requires additional Vault configuration
   - Changes to path prefixes require updating Vault and redeploying

3. **OCFP Integration**
   - This feature can be used with the `ocfp` feature
   - When combined, it enables custom path prefixes for each environment in the OCFP architecture

4. **Vault Permissions**
   - Ensure Doomsday has permission to read all the configured paths
   - Consider using a dedicated policy for Doomsday with appropriate access