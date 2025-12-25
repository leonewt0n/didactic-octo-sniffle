# Display block devices
echo "Available block devices:"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT

# Prompt user to pick a device
read -p "Enter the NAME of the device you want to install to (e.g., sda, nvme0n1): " selected_device_name

# Construct the full path
disk="/dev/${selected_device_name}"

# Verify the selected device is a block device
if [[ ! -b "$disk" ]]; then
    echo "Error: '$disk' is not a valid block device or does not exist."
    exit 1
fi

echo "You selected: $disk"

# Determine partition naming convention
# If the disk name ends in a number (like nvme0n1), add 'p' before the partition number.
# Otherwise (like sda), just append the number.
if [[ "$selected_device_name" =~ [0-9]$ ]]; then
    part_prefix="${disk}p"
else
    part_prefix="${disk}"
fi

# Wipe and Partition
sgdisk --zap-all "$disk"
parted -s "$disk" mklabel gpt
parted -s "$disk" mkpart ESP fat32 1MiB 1000MiB
parted -s "$disk" set 1 esp on
parted -s "$disk" mkpart primary btrfs 1000MiB 100%
cryptsetup luksFormat "$disk""p2"
cryptsetup open "$disk""p2" enc
#Create Filesystems
mkfs.fat -F32 "$disk""p1"
mkfs.btrfs -L nixos /dev/mapper/enc
mount "$disk""p2" /mnt
mkdir -p /mnt/boot
mount "$disk""p1" /mnt/boot
mkdir -p /mnt/etc/nixos
nix-channel --add https://nixos.org/channels/nixos-unstable nixos
nix-channel --update
nixos-generate-config --root /mnt
nixos-install  /mnt/etc/nixos/configuration.nix --no-root-password

