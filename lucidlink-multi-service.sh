#!/bin/bash

# Display help message
show_help() {
    cat << EOF

Usage: $(basename "$0") [OPTIONS]

Create and configure multiple LucidLink service instances.

Required Options:
    --fs              Filespace name
    --user            Filespace user
    --mount-base      Base mount point directory
    --cache-location  Location for data cache
    --cache-size      Size of data cache
    --number          Number of instances to create

Optional Options:
    -h, --help       Display this help message

Password:
    The script will prompt securely for your LucidLink password.
    The password is encrypted using systemd-creds and stored securely
    for each service instance.

Example:
    $(basename "$0") --fs production.dpfs --user admin --mount-base /mnt/lucid \\
        --cache-location /var/cache/lucid --cache-size 20GB --number 3

The script will:
1. Create systemd service files for each instance
2. Configure secure password handling using systemd-creds
3. Set up mount points and cache
4. Enable and start services

EOF
    exit 1
}

# Check if no arguments provided
if [ $# -eq 0 ]; then
    echo ""
    echo "Error: No arguments provided"
    show_help
fi

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            ;;
        --fs)
            FS="$2"
            shift 2
            ;;
        --user)
            FSUSER="$2"
            shift 2
            ;;
        --mount-base)
            MOUNT_BASE="$2"
            shift 2
            ;;
        --cache-location)
            CACHE_LOCATION="$2"
            shift 2
            ;;
        --cache-size)
            CACHE_SIZE="$2"
            shift 2
            ;;
        --number)
            NUMBER="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$FS" || -z "$FSUSER" || -z "$MOUNT_BASE" || -z "$NUMBER" || -z "$CACHE_LOCATION" || -z "$CACHE_SIZE" ]]; then
    echo "Missing required arguments!"
    exit 1
fi

# Setup sudo to allow no-password sudo for "lucidlink" group and adding "lucidlink" user
sudo groupadd -r lucidlink || echo "Group lucidlink already exists"
sudo useradd -M -r -g lucidlink lucidlink || echo "System user lucidlink already exists"
sudo useradd -m -s /bin/bash lucidlink || echo "User lucidlink already exists"
sudo usermod -a -G lucidlink lucidlink || echo "User already in group"
sudo cp /etc/sudoers /etc/sudoers.orig 2>/dev/null || true
echo "lucidlink  ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/lucidlink

# Set permissions and update fuse.conf
sudo mkdir -p /client/lucid
sudo chown -R lucidlink:lucidlink /client/lucid
sudo chmod 700 -R /client/lucid
sudo sed -i -e 's/#user_allow_other/user_allow_other/g' /etc/fuse.conf

# Get password securely
read -sp "Enter password: " LLPASSWD
echo

# Validate required arguments
if [[ -z "$LLPASSWD" ]]; then
    echo "Missing required password!"
    exit 1
fi

# Create credential store directory
sudo mkdir -p /etc/credstore
sudo chmod 700 /etc/credstore

# Generate services in a loop
for ((i=1; i<=NUMBER; i++)); do
    INSTANCE_NUM=$((500 + i))
    SERVICE_NAME="lucidlink-${i}"
    
    # Encrypt password for this service instance
    echo -n "${LLPASSWD}" | sudo systemd-creds encrypt --name=lucidlink-${i} - /etc/credstore/lucidlink-${i}.cred
    sudo chmod 600 "/etc/credstore/lucidlink-${i}.cred"
    
    # Create variables file
    cat >"/client/lucid/lucidlink-service-vars${i}.txt" <<EOF
FILESPACE="${FS}"
FSUSER="${FSUSER}"
MOUNTPOINT="${MOUNT_BASE}/lucidlink-${i}"
CONFIGPATH="/client/lucid/lucidlink-${i}"
EOF

    # Create service file
    cat >"/client/lucid/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=LucidLink Daemon ${i}
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=0

[Service]
Restart=on-failure
RestartSec=1
TimeoutStartSec=180
Type=exec
User=lucidlink
Group=lucidlink
WorkingDirectory=/client/lucid
EnvironmentFile=/client/lucid/lucidlink-service-vars${i}.txt
LoadCredentialEncrypted=lucidlink-${i}:/etc/credstore/lucidlink-${i}.cred
ExecStart=/bin/bash -c "/usr/bin/systemd-creds cat lucidlink-${i} | /usr/bin/lucid2 --instance ${INSTANCE_NUM} daemon --fs \${FILESPACE} --user \${FSUSER} --mount-point \${MOUNTPOINT} --root-path \${CONFIGPATH} --config-path \${CONFIGPATH} --fuse-allow-other"
ExecStop=/usr/bin/lucid2 exit

[Install]
WantedBy=multi-user.target
EOF

    # Install service file
    sudo mv "/client/lucid/${SERVICE_NAME}.service" "/etc/systemd/system/${SERVICE_NAME}.service"
    sudo chmod 644 "/etc/systemd/system/${SERVICE_NAME}.service"

    echo "Enabling 'systemctl enable lucidlink-${i}.service'"
    sudo systemctl enable lucidlink-${i}.service
    wait
    echo "Starting 'systemctl start lucidlink-${i}.service'"
    sudo systemctl start lucidlink-${i}.service
    wait
    until /usr/bin/lucid2 --instance ${INSTANCE_NUM} status | grep -qo "Linked"
    do
        sleep 1
    done
    sleep 1
    /usr/bin/lucid2 --instance ${INSTANCE_NUM} config --set --DataCache.Location ${CACHE_LOCATION}
    sleep 1
    /usr/bin/lucid2 --instance ${INSTANCE_NUM} config --set --DataCache.Size ${CACHE_SIZE}
    sleep 1
    echo "Restarting 'systemctl start lucidlink-${i}.service'"
    sudo systemctl restart lucidlink-${i}.service
done

# Cleanup credentials from memory
unset LLPASSWD

exit 0
