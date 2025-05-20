# Doomsday Genesis Kit

The **Doomsday Genesis Kit** provides a streamlined way to deploy and manage the Doomsday certificate monitoring service using the Genesis deployment system. Doomsday helps you track and monitor certificate expirations across multiple systems, providing alerts before certificates expire to prevent service outages.

## What is Doomsday?

Doomsday is an automated certificate monitoring tool that:

- Monitors X.509 TLS certificates across multiple platforms
- Identifies certificates approaching expiration
- Provides a dashboard for certificate health visibility
- Allows you to centralize certificate monitoring in a single location

Doomsday can monitor certificates in:
- BOSH deployments (via Credhub)
- HashiCorp Vault
- Network endpoints (via TLS client)
- Additional backends available through plugins

## Architecture Overview

Doomsday consists of:

1. **Doomsday Server**: The core service that connects to certificate sources
2. **Backend Connectors**: Adapters that fetch certificates from different systems
3. **Web Interface**: A dashboard for viewing certificate status and expiration

When using the OCFP (Open Cloud Foundry Platform) reference architecture, Doomsday is deployed in the management environment and configured to automatically monitor certificates across all connected environments.

## Quick Start

To use this kit, you don't even need to clone this repository. With Genesis v2+:

```bash
# Create a doomsday-deployments repo using the latest version of the doomsday kit
genesis init --kit doomsday

# Create a doomsday-deployments repo using a specific version
genesis init --kit doomsday/1.0.0

# Create with a custom repo name
genesis init --kit doomsday -d my-doomsday-configs
```

Once created, follow these steps:

1. Create an environment YAML file
2. Configure your cloud config (if not using OCFP)
3. Deploy Doomsday with `genesis deploy`
4. Access the Doomsday UI through its IP or FQDN

For detailed instructions, refer to the `MANUAL.md` file.

## Features

The Doomsday Genesis Kit offers the following features:

### Core Features

- **ocfp**: *(Open Cloud Foundry Platform)* - Deploys Doomsday according to the OCFP reference architecture. Automatically enables `tls`, `lb`, and `userpass` features.

### Authentication Features

- **userpass**: Enables username/password authentication for accessing the Doomsday UI.

### Network Features

- **tls**: Enables HTTPS for the Doomsday UI using TLS certificates.
- **lb**: Configures Doomsday instances for use behind a load balancer.

### Storage Features

- **sharded-vault-paths**: Allows configuration of custom Vault path prefixes for certificate scanning. *(Not recommended for most deployments)*

## Supported IaaS Providers

The Doomsday Genesis Kit supports deployment across multiple infrastructure providers:

- OpenStack
- STACKIT
- vSphere
- GCP

Each IaaS provider has specific configuration requirements. See `MANUAL.md` for details.

## Requirements

- Genesis 2.8.7+
- A BOSH director
- Access to the Doomsday BOSH release

## More Information

- [Detailed Manual](MANUAL.md)
- [Doomsday BOSH Release](https://github.com/doomsday-project/doomsday-boshrelease)
- [Deployment Documentation](docs/README.md)