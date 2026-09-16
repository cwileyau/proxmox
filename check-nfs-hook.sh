#!/usr/bin/env bash

#on PVE console, assign script to VM's: qm set 104 -hookscript local:snippets/check-nfs-hook.sh
# ==============================================================================
# CONFIGURATION
# ==============================================================================
# The exact ID of your NFS storage in Proxmox (e.g., Datacenter -> Storage)
NFS_STORAGE_ID="nfs" 

# Timeout configurations
MAX_ATTEMPTS=30
SLEEP_INTERVAL=1m
# ==============================================================================

VMID="$1"
PHASE="$2"

# We only want to intercept the pre-start phase
if [ "$PHASE" = "pre-start" ]; then
    echo "Hookscript: [VM/CT $VMID] Entering pre-start phase."
    
    # 1. Dynamically find where Proxmox expects this NFS share to be mounted
    # Proxmox stores storage configs in /etc/pve/storage.cfg
    NFS_PATH="/mnt/pve/${NFS_STORAGE_ID}"
    
    echo "Hookscript: Monitoring mount point availability at ${NFS_PATH}..."

    attempt=1
    while [ $attempt -le $MAX_ATTEMPTS ]; do
        
        # 2. Check if the directory is explicitly active in the system mounts
        # We append a '|| true' flag so an unavailable share never crashes the bash execution loop
        if mountpoint -q "$NFS_PATH" 2>/dev/null; then
            
            # Double-check readability to ensure it isn't a stale/hung mount
            if ls "$NFS_PATH" >/dev/null 2>&1; then
                echo "Hookscript: Success! NFS path '${NFS_PATH}' is mounted and reachable."
                exit 0
            fi
        fi

        echo "Hookscript: [Attempt $attempt/$MAX_ATTEMPTS] NFS storage is offline. Waiting ${SLEEP_INTERVAL}..."
        sleep "$SLEEP_INTERVAL"
        attempt=$((attempt + 1))
    done

    # If it falls through the loop, the storage failed to come online
    echo "Hookscript: ERROR - NFS storage for '${NFS_STORAGE_ID}' remained unavailable after $((MAX_ATTEMPTS * SLEEP_INTERVAL)) minutes." >&2
    echo "Hookscript: Aborting boot sequence for VM/CT $VMID." >&2
    exit 1
fi

# Allow all other phases to pass through
exit 0
