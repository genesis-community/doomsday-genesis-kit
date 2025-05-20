# Doomsday Architecture Overview

This document provides an overview of the Doomsday certificate monitoring service architecture and how it's deployed using the Doomsday Genesis Kit.

## What is Doomsday?

Doomsday is a certificate monitoring system designed to track X.509 certificates across various platforms and alert when certificates are approaching expiration. This helps prevent outages due to expired certificates by providing a centralized view of certificate health.

## System Components

The Doomsday system consists of the following key components:

### Doomsday Server

The core server component that:
- Provides a web interface for viewing certificate information
- Manages backend connectors
- Stores certificate information
- Calculates expiration timelines and alerts

### Backend Connectors

Pluggable components that fetch certificates from various sources:

1. **BOSH/CredhHub Connector**
   - Connects to BOSH directors
   - Scans CredhHub for certificates
   - Monitors certificates used in BOSH deployments

2. **Vault Connector**
   - Connects to HashiCorp Vault
   - Scans specified paths for certificates
   - Monitors certificates stored in Vault

3. **TLS Client Connector**
   - Connects to specified hostnames
   - Performs TLS handshakes to retrieve certificates
   - Monitors certificates on network endpoints

Additional connectors can be developed as plugins.

### Web Interface

A user interface that:
- Displays certificate information
- Shows expiration timelines
- Provides filtering and sorting
- Allows configuring alerting thresholds

## Deployment Architecture

When deployed with the Doomsday Genesis Kit, the system architecture follows this pattern:

### Basic Deployment

In a basic deployment:
- Single Doomsday VM running the server
- Manually configured backend connectors
- Accessible via IP or FQDN
- Optional TLS for secure access
- Optional user authentication

```
                   ┌───────────────────┐
                   │                   │
 ┌───────────┐     │  Doomsday Server  │     ┌───────────┐
 │           │     │                   │     │           │
 │  Web UI   │◄────►  Backend Manager  │────►│  Backend  │
 │           │     │                   │     │ Connectors│
 └───────────┘     │  Certificate DB   │     └───────────┘
                   │                   │           │
                   └───────────────────┘           │
                                                  │
                                                  ▼
                               ┌──────────────────────────────┐
                               │                              │
                               │  Certificate Sources         │
                               │  - BOSH/CredhHub            │
                               │  - Vault                    │
                               │  - Network Endpoints        │
                               │                              │
                               └──────────────────────────────┘
```

### OCFP Reference Architecture

In an OCFP (Open Cloud Foundry Platform) deployment:
- Doomsday is deployed in the management environment
- Automatically configured to monitor:
  - All connected BOSH directors
  - Vault paths
  - FQDNs from Terraform outputs
- Deployed behind a load balancer
- TLS-enabled for secure access
- User authentication required

```
                                ┌─────────────┐
                                │             │
                                │    Load     │
                                │  Balancer   │
                                │             │
                                └──────┬──────┘
                                       │
                                       ▼
                                ┌─────────────┐
                                │             │
┌──────────────┐               │  Doomsday    │                ┌──────────────┐
│              │               │   Server     │                │              │
│  Management  │◄──────────────►    VM       │◄───────────────►   Platform   │
│   Vault      │               │             │                │    BOSH      │
│              │               └─────────────┘                │              │
└──────────────┘                      │                       └──────────────┘
                                      │                                │
                                      │                                │
                                      │                                │
                                      ▼                                ▼
                     ┌────────────────────────────┐      ┌───────────────────────┐
                     │                            │      │                       │
                     │  Management Environment    │      │  Platform Environment │
                     │  - Vault Certificates      │      │  - BOSH Deployments   │
                     │  - BOSH Director Certs     │      │  - CredhHub Certs     │
                     │  - Management FQDNs        │      │  - Platform FQDNs     │
                     │                            │      │                       │
                     └────────────────────────────┘      └───────────────────────┘
```

## Data Flow

The data flow in a Doomsday deployment follows this pattern:

1. **Certificate Discovery**
   - Backends connect to certificate sources
   - Extract certificates and metadata
   - Return certificate data to Doomsday server

2. **Certificate Processing**
   - Server processes certificate data
   - Extracts expiration dates and other metadata
   - Calculates time remaining
   - Determines alert status

3. **User Interface**
   - Web UI fetches certificate data from server
   - Displays certificates with expiration timelines
   - Provides filtering and sorting
   - Shows alerts for expiring certificates

4. **Automated Scanning**
   - Doomsday periodically rescans all backends
   - Updates certificate information
   - Refreshes alert status

## Security Considerations

The Doomsday deployment includes several security features:

1. **TLS Encryption**
   - Web interface secured with HTTPS
   - Backend communications encrypted
   - Certificates managed through Vault

2. **Authentication**
   - User authentication for accessing the UI
   - Session management and timeout
   - Role-based access control (where applicable)

3. **Backend Security**
   - Secure storage of credentials in Vault
   - Minimal permissions for backend connectors
   - Secure connections to certificate sources

## BOSH Deployment Architecture

When deployed via the Doomsday Genesis Kit, the BOSH deployment includes:

- **Single Instance Group**: `doomsday`
  - Runs the Doomsday server
  - Configured with appropriate network settings
  - Includes all necessary backend connectors

- **Persistent Disk**:
  - Stores certificate database
  - Preserves configuration across restarts

- **Networking**:
  - Static IP for direct access
  - Optional load balancer configuration
  - Firewall rules for accessing certificate sources

## Integration Points

Doomsday integrates with several external systems:

1. **BOSH Directors**
   - Connects to BOSH API
   - Accesses Credhub for certificate data
   - Monitors BOSH deployments

2. **Vault**
   - Connects to Vault API
   - Scans paths for certificates
   - Uses secure authentication

3. **Network Endpoints**
   - Performs TLS handshakes with hosts
   - Retrieves certificate information
   - Monitors certificate expiration

## Monitoring and Maintenance

For operational concerns:

1. **Monitoring Doomsday**
   - BOSH health monitoring
   - VM resource utilization
   - Process health checks

2. **Backup and Restore**
   - BOSH backup and restore (BBR) compatible
   - Configuration stored in Vault
   - Persistent disk for database

3. **Scaling**
   - Vertical scaling through VM sizing
   - Resource allocation based on number of certificates

## Conclusion

The Doomsday certificate monitoring system provides a comprehensive solution for tracking certificates across your infrastructure. When deployed using the Doomsday Genesis Kit, it is easily integrated into your environment and configured to automatically discover and monitor certificates from multiple sources.