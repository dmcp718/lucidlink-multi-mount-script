# LucidLink Multi-Service Setup Script

This script automates the creation and configuration of multiple LucidLink v2.x service instances on a Linux system using systemd.

## Features

- Creates multiple LucidLink service instances
- Securely handles credentials using systemd-creds
- Configures mount points and data cache for each instance
- Automatically enables and starts services
- Waits for services to be fully linked before proceeding

## Prerequisites

- Linux system with systemd (version 250 or later)
- sudo privileges
- LucidLink client (lucidlink v2.x) installed
- systemd-creds available (systemd version 250 or higher)

## Setup

1. Clone the repository:
```bash
git clone https://github.com/dmcp718/lucidlink-multi-mount-script.git
```

2. Navigate to the repository directory:
```bash
cd lucidlink-multi-mount-script
```

3. Make the script executable:
```bash
chmod +x lucidlink-multi-service.sh
```

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

### Managing Service Instances

The script creates systemd services named `lucidlink-N.service`, where N is the instance number (1, 2, 3, etc.).
Each instance has its own:
- Service name: `lucidlink-N.service`
- Mount point: `/mnt/lucid/lucidlink-N`
- Configuration directory: `/client/lucid/lucidlink-N`
- Instance number: `50N` (e.g., 501, 502, 503)

#### Service Management Commands

Each service instance must be managed individually. For example, with 3 instances:

Start instances:
```bash
sudo systemctl start lucidlink-1.service
sudo systemctl start lucidlink-2.service
sudo systemctl start lucidlink-3.service
```

Stop instances:
```bash
sudo systemctl stop lucidlink-1.service
sudo systemctl stop lucidlink-2.service
sudo systemctl stop lucidlink-3.service
```

Restart a specific instance:
```bash
sudo systemctl restart lucidlink-2.service
```

Check status of instances:
```bash
sudo systemctl status lucidlink-1.service  # systemd service status
/usr/bin/lucid2 --instance 501 status     # LucidLink status for instance 1
```

View logs for a specific instance:
```bash
sudo journalctl -u lucidlink-1.service
```

Note: For best results manage each service separately. Wildcard patterns (like `lucidlink-*.service`) may not be reliable for managing multiple services at once.

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
