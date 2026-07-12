mkdir -p /mnt

echo "--- erasing system state begin ---"
# We first mount the btrfs root to /mnt
# so we can manipulate btrfs subvolumes.
mount -o subvol=/ "$_ERASURE_MAPPER_DEVICE" /mnt

# back up the old root (important!!)
BOOTID=$(date +"@boot-%Y_%m_%d-%H_%M_%S-%s")
echo "backing up old root: /mnt/@root/ -> /mnt/@old-roots/$BOOTID..."
echo "note that the timestamp is of *this* boot, not of the boot that created the old root!"
mv /mnt/@root /mnt/@old-roots/$BOOTID
btrfs property set -f -ts /mnt/@old-roots/$BOOTID ro true

echo "restoring blank /@root subvolume..."
btrfs subvolume snapshot /mnt/@root-blank /mnt/@root

# Once we're done rolling back to a blank snapshot,
# we can unmount /mnt and continue on the boot process.
echo "--- erasing system state end ---"

umount /mnt
