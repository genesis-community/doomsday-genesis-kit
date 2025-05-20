# UserPass Feature

The `userpass` feature enables username/password authentication for accessing the Doomsday web interface, providing security and access control.

## Overview

When enabled, the `userpass` feature:

1. Configures Doomsday to require username/password authentication
2. Creates an admin user with credentials stored in Vault
3. Configures session timeout and refresh settings
4. Exports the admin credentials in the Genesis exodus data

## Configuration

### Enabling the Feature

Add `userpass` to your environment's feature list:

```yaml
---
features:
- userpass
```

This feature is automatically enabled when using the `ocfp` feature.

### Parameters

The following parameters affect authentication configuration:

- `server_auth_timeout`: Session timeout in minutes for authenticated users. Defaults to 30 minutes.
- `server_auth_refresh`: Whether to refresh authentication sessions. Defaults to `true`.

## Behavior

When the `userpass` feature is enabled:

1. **Credential Management**
   - Genesis creates an admin user with username `admin`
   - A random password is generated and stored in Vault
   - Credentials can be retrieved using `genesis <env> secrets users/admin:password`

2. **Authentication Configuration**
   - Doomsday is configured to require authentication
   - Session timeout is set according to `server_auth_timeout`
   - Session refresh is enabled or disabled according to `server_auth_refresh`

3. **User Experience**
   - Users are presented with a login page when accessing Doomsday
   - After authentication, users have access to the Doomsday UI
   - Sessions expire after the configured timeout period

## Implementation Details

The UserPass feature is implemented through the `manifests/addons/userpass.yml` file, which:

1. Defines the admin username
2. Retrieves the admin password from Vault
3. Configures Doomsday with authentication settings
4. Adds the admin credentials to the deployment's exodus data

The credentials are defined in `kit.yml`:

```yaml
credentials:
  userpass:
    users/admin:
      password: random 30
```

## Accessing Doomsday with Authentication

With UserPass enabled, when you access Doomsday, you'll be presented with a login page:

1. Enter username: `admin`
2. Enter password: Retrieved from Vault using `genesis <env> secrets users/admin:password`

## Example

Here's an example of an environment file using the UserPass feature:

```yaml
---
# userpass-deployment.yml

# Network definition
networks:
- name: default
  static: [10.0.0.10]

# Required parameters
params:
  ip: 10.0.0.10
  
  # Custom authentication configuration
  server_auth_timeout: 60  # 60 minute session timeout
  server_auth_refresh: false  # Disable session refresh
  
# Enable authentication
features:
- userpass
```

## Considerations

1. **Password Management**
   - The admin password is automatically generated and stored in Vault
   - Consider rotating the password periodically with `genesis rotate-secrets <env>`

2. **Session Settings**
   - Shorter timeout periods enhance security but may inconvenience users
   - Session refresh allows users to maintain their session while actively using Doomsday

3. **Multi-User Access**
   - Currently, the kit only configures a single admin user
   - If multiple users with different permissions are needed, consider alternative authentication methods

4. **Secure Access**
   - Combine the `userpass` feature with the `tls` feature for secure authentication
   - Without TLS, credentials are transmitted in the clear