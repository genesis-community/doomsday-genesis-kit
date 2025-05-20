# Doomsday Genesis Kit Documentation

Welcome to the documentation for the Doomsday Genesis Kit, which deploys and manages the Doomsday certificate monitoring service.

## Documentation Structure

- **[Architecture](architecture/)**: Understand how Doomsday works and its components
  - [Overview](architecture/overview.md): High-level architecture of Doomsday

- **[Deployment](deployment/)**: Instructions for deploying Doomsday
  - [Prerequisites](deployment/prerequisites.md): Requirements before deployment
  - [Installation](deployment/installation.md): Step-by-step installation guide

- **[Features](features/)**: Detailed documentation for each feature
  - [OCFP](features/ocfp.md): Open Cloud Foundry Platform integration
  - [TLS](features/tls.md): HTTPS support for secure access
  - [Load Balancer](features/lb.md): Deployment behind a load balancer
  - [UserPass](features/userpass.md): Username/password authentication
  - [Sharded Vault Paths](features/sharded-vault-paths.md): Custom Vault path configuration

- **[IaaS Providers](iaas/)**: IaaS-specific configuration and guidance
  - [OpenStack](iaas/openstack.md): Deploying on OpenStack
  - [STACKIT](iaas/stackit.md): Deploying on STACKIT infrastructure

- **[Operations](operations/)**: Day-to-day operational guidance
  - [Troubleshooting](operations/troubleshooting.md): Solving common issues

- **[Examples](examples/)**: Example deployment configurations
  - [Deployment Examples](examples/deployment-examples.md): Various deployment scenarios

## Quick Links

- [Main README](../README.md): Overview and quick start
- [Manual](../MANUAL.md): Comprehensive user manual
- [Doomsday BOSH Release](https://github.com/doomsday-project/doomsday-boshrelease): Upstream project

## Getting Help

If you encounter issues or have questions about deploying Doomsday with this Genesis kit, please reach out to your Genesis administrator or file an issue on the [GitHub repository](https://github.com/genesis-community/doomsday-genesis-kit).