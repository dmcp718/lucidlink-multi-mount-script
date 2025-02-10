# LucidLink Multi-Service Setup Script

This script automates the creation and configuration of multiple LucidLink service instances on a Linux system using systemd.

## Features

- Creates multiple LucidLink service instances
- Securely handles credentials using systemd-creds
- Configures mount points and data cache for each instance
- Automatically enables and starts services
- Waits for services to be fully linked before proceeding

## Prerequisites

- Linux system with systemd
- sudo privileges
- LucidLink client (lucidlink v2.x) installed
- systemd-creds available (systemd version 250 or higher)

## Usage

```bash
./lucidlink-multi-service.sh [OPTIONS]
```

### Required Options

- `--fs`: Filespace name
- `--user`: Filespace user
- `--mount-base`: Base mount point directory
- `--cache-location`: Location for data cache
- `--cache-size`: Size of data cache
- `--number`: Number of instances to create

### Password Input

The script will securely prompt for your LucidLink password. This password is:
- Never stored in plaintext
- Encrypted using systemd-creds for each service instance
- Stored securely in `/etc/credstore/`
- Automatically cleaned from memory after setup
- Passed securely to each service instance at runtime

### Optional Options

- `-h, --help`: Display help message

### Example

```bash
./lucidlink-multi-service.sh \
    --fs production.dpfs \
    --user admin \
    --mount-base /mnt/lucid \
    --cache-location /var/cache/lucid \
    --cache-size 20GB \
    --number 3
```

## What the Script Does

1. **Setup Phase**
   - Creates lucidlink user and group
   - Configures sudo permissions
   - Sets up mount points and FUSE configuration

2. **Service Creation**
   - Generates systemd service files for each instance
   - Creates secure credential storage
   - Configures environment variables

3. **Service Configuration**
   - Sets up unique mount points for each instance
   - Configures data cache location and size
   - Enables and starts services

4. **Security**
   - Passwords are securely handled:
     - Collected via secure prompt (no command line arguments)
     - Encrypted using systemd-creds
     - Stored in `/etc/credstore/` with proper permissions (600)
     - Never exposed in process listings or environment variables
     - Cleaned from memory after use
   - Proper file permissions are set
   - Credentials are cleaned from memory after use

## Directory Structure

- `/etc/systemd/system/lucidlink-*.service`: Service files
- `/client/lucid/`: Working directory for LucidLink
- `/etc/credstore/`: Secure credential storage
- `${mount-base}/lucidlink-*`: Mount points for each instance

## Notes

- Instance numbers start at 501 and increment for each service
- Each service gets its own configuration and mount point
- Services are automatically enabled and started
- The script waits for each service to be fully linked before proceeding

## Troubleshooting

If services fail to start:
1. Check systemd logs: `journalctl -u lucidlink-*.service`
2. Verify mount points are accessible
3. Ensure cache locations exist and have proper permissions
4. Check credential encryption status
