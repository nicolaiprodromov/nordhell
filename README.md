# LLUSTR Proxy

A Docker-based proxy system that uses NordVPN configurations for maintaining multiple SOCKS5 proxy connections through different VPN servers.

## Project Structure

- `Dockerfile` - Container configuration for the VPN proxy
- `docker-compose.yml` - Multi-container setup
- `start.sh` - Script to start VPN tunnels with specific configs
- `status.sh` - Script to list all active VPN tunnels
- `stop.sh` - Script to stop specific or all VPN tunnels
- `scripts/` - Additional shell scripts for system operation
  - `entrypoint.sh` - Container startup script
- `configs/` - Configuration files
  - `sockd.conf` - Dante SOCKS proxy configuration
- `utils/` - Utility scripts
  - `download_nordvpn_configs.py` - Script for downloading NordVPN configuration files
- `tests/` - Test files for the proxy functionality
- `vpn-configs/` - Directory for VPN configuration files

## Setup

1. Clone this repository
2. Set up authentication information in a `.env` file with the following format:
   ```
   VPN_USERNAME=your_username
   VPN_PASSWORD=your_password
   ```
   Note: For improved security, these credentials are stored in a memory-only filesystem 
   inside the container and are never written to persistent storage.
3. Make sure you have VPN configuration files in the vpn-configs directory

## Usage

### Starting VPN Tunnels

Start a VPN tunnel using a specific configuration:
```bash
./start.sh 29  # Start a tunnel with config #29 (numbered by filename prefix)
```

Start multiple VPN tunnels using a range:
```bash
./start.sh 0-4  # Start tunnels for configs 0, 1, 2, 3, and 4
```

Force rebuild of a VPN tunnel image:
```bash
./start.sh --build 29  # Start a tunnel with config #29 and force a rebuild
```

Update VPN configuration files before starting a tunnel:
```bash
./start.sh --update-configs 29  # Download fresh NordVPN configs, then start tunnel #29
```

Options can be combined:
```bash
./start.sh --update-configs --build 0-4  # Update configs, force rebuild, and start tunnels 0-4
```

**Note:** If no VPN configuration files are found in the `vpn-configs` directory, the script will automatically download them even if the `--update-configs` flag is not provided.

By default, tunnels will only be rebuilt when necessary (when configuration files have changed).

### Managing VPN Tunnels

List all active VPN tunnels:
```bash
./status.sh
```

Stop a specific VPN tunnel:
```bash
./stop.sh 29  # Stop the tunnel using config #29
```

Stop all VPN tunnels:
```bash
./stop.sh all
```

### Using the SOCKS5 Proxy

Each VPN tunnel exposes a SOCKS5 proxy on a different port, starting from 1080. To use with curl:

```bash
export http_proxy=socks5h://localhost:1080
export https_proxy=socks5h://localhost:1080
curl https://ipinfo.io
```

## Notes

VPN configuration files are stored in the vpn-configs directory but are excluded from the repository for security reasons.

The system automatically assigns sequential ports starting from 1080 for each VPN tunnel.

## Security Considerations

This system implements several security measures:

1. Credentials are stored in a `.env` file that is excluded from git via `.gitignore`
2. Inside containers, credentials are stored in a memory-only tmpfs filesystem, not on disk
3. All credential files have strict 600 permissions (owner read/write only)
4. The tmpfs filesystem is automatically cleared when the container stops
5. Environment variables are cleared after use to prevent leakage
6. Credentials file is securely wiped from memory after OpenVPN connects

### Using Certificate-Based Authentication (Recommended)

For maximum security, consider switching to certificate-based authentication instead of username/password:

1. **Generate certificates**:
   ```
   # Install easy-rsa
   apt-get install easy-rsa
   
   # Set up PKI
   mkdir ~/openvpn-ca
   cd ~/openvpn-ca
   /usr/share/easy-rsa/easyrsa init-pki
   /usr/share/easy-rsa/easyrsa build-ca
   
   # Generate server certificate
   /usr/share/easy-rsa/easyrsa build-server-full server nopass
   
   # Generate client certificate
   /usr/share/easy-rsa/easyrsa build-client-full client1 nopass
   ```

2. **Configure OpenVPN server to use certificates**:
   ```
   # In server config
   ca ca.crt
   cert server.crt
   key server.key
   ```

3. **Configure client to use certificate**:
   ```
   # In client config
   ca ca.crt
   cert client1.crt
   key client1.key
   ```

With certificate-based authentication, no username/password is needed, eliminating the need for credential storage.

### Authentication Security Hierarchy

From most to least secure, here are the OpenVPN authentication options:

1. **Certificate-based authentication**: Each client has a unique certificate
2. **Multi-factor authentication**: Combining certificates with another factor like TOTP
3. **Docker Swarm secrets**: Native secrets management for Docker (requires Swarm mode)
4. **External secrets manager**: HashiCorp Vault, AWS Secrets Manager, etc.
5. **Memory-only tmpfs credentials**: Our current implementation
6. **Environment variables**: Less secure but convenient
7. **Hardcoded credentials**: Should never be used

### Additional Security Recommendations

For production deployments, consider these additional security measures:

- **Certificate-based authentication**: Configure OpenVPN to use client certificates instead of username/password
- **Secret management**: Use Docker Secrets (Swarm), HashiCorp Vault, or cloud provider secret managers
- **Network security**: Implement network-level security to limit access to your proxy containers
- **Credential rotation**: Regularly rotate VPN credentials and revoke compromised certificates
- **Audit logging**: Enable logging of authentication attempts and review logs regularly
- **Secure TLS**: Ensure OpenVPN uses at least TLS 1.2 with strong ciphers
- **Container hardening**: Run containers with minimal privileges and read-only filesystems where possible

## TODO

- Implement certificate-based authentication for OpenVPN connections to eliminate the need for username/password credentials entirely
- Create a script to automatically generate client certificates for each tunnel
- Update the Docker configuration to mount certificates instead of using environment variables
- Add documentation for certificate management and rotation
- Add support for certificate revocation lists (CRLs)
