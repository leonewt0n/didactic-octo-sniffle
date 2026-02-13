# Hardened NixOS: Impermanence, Lanzaboote Secure Boot, & Yubikey MFA

A high-security, stateless configuration for NixOS on **Intel Core Ultra 200 series (265K)** systems with Intel GPU support. This setup ensures a "fresh" system on every boot while maintaining critical data through hardware-backed encryption.

## Key Security Features
* **Impermanence:** Root and Home directories are wiped on every reboot. Only whitelisted data (defined in your Nix config) is stored on the `persistent` subvolume.
* **Secure Boot (Lanzaboote):** Full UEFI Secure Boot support for NixOS.
* **TPM 2.0 LUKS Unlock:** Automated, secure disk decryption tied to your system's hardware state (PCRs 0, 2, 7).
* **Multi-Factor Authentication:** Yubikey U2F required for `login` and `sudo`.
* **Stateless Configuration:** Single source of truth via `flake.nix` synced to GitHub.
* **Hardened Environment:** Root account is locked, and non-FHS compliance blocks unauthorized or undeclared binaries.

---

## Installation & Partitioning

### 1. Prepare Partitions
```bash
# Create GPT label
parted /dev/nvme0n1 -- mklabel gpt

# Create ESP (Partition 1 - 1.5GB for Lanzaboote)
parted /dev/nvme0n1 -- mkpart ESP fat32 1MB 1500MB
parted /dev/nvme0n1 -- set 1 esp on

# Create LUKS Container (Partition 2)
parted /dev/nvme0n1 -- mkpart primary 1500MB 100%

# Setup Encryption
cryptsetup luksFormat /dev/nvme0n1p2
cryptsetup open /dev/nvme0n1p2 enc
```

### 2. Btrfs Subvolumes for Impermanence
```bash
# Format Boot
mkfs.fat -F 32 -n boot /dev/nvme0n1p1

# Format Root
mkfs.btrfs -L root /dev/mapper/enc

# Create Subvolumes
mount /dev/mapper/enc /mnt
btrfs subvolume create /mnt/root
btrfs subvolume create /mnt/clean-root
btrfs subvolume create /mnt/nix
btrfs subvolume create /mnt/persistent
umount /mnt
```

### 3. Mount and Install
```bash
# Mount Root
mount -o subvol=root,compress=zstd /dev/mapper/enc /mnt

# Create and Mount Sub-targets
mkdir -p /mnt/{nix,persistent,boot}
mount -o subvol=nix,compress=zstd,noatime /dev/mapper/enc /mnt/nix
mount -o subvol=persistent,compress=zstd /dev/mapper/enc /mnt/persistent
mount /dev/nvme0n1p1 /mnt/boot

# Run Installer
nixos-generate-config --root /mnt
cd /mnt/etc/nixos
git init && git add .
nixos-install --flake .#nixos
```

---

## Hardware-Backed Hardening

### Yubikey MFA Setup
Run this after your first boot to enroll your hardware key for U2F.
```bash
mkdir -p ~/.config/Yubico
pamu2fcfg > ~/.config/Yubico/u2f_keys
```

### Lanzaboote (Secure Boot)
Ensure your BIOS is in **"Setup Mode"** before enrolling keys.
```bash
nix-shell -p sbctl
sudo sbctl create-keys
sudo sbctl enroll-keys -m -f
```

### TPM 2.0 Disk Decryption
Bind your LUKS key to the TPM 2.0 chip.
```bash
# Wipe existing slots and bind to PCRs 0+2+7
sudo systemd-cryptenroll --wipe-slot=tpm2 /dev/nvme0n1p2
sudo systemd-cryptenroll /dev/nvme0n1p2 --tpm2-device=auto --tpm2-pcrs=0+2+7
```

---

## Recovery & Reinstallation
Since the system is stateless, you can "factory reset" by wiping the root subvolume.

### Step 1: Wipe Existing Root
```bash
cryptsetup open /dev/nvme0n1p2 enc
mount /dev/mapper/enc /mnt
btrfs subvolume delete /mnt/root
btrfs subvolume create /mnt/root
umount /mnt
```

### Step 2: Remount and Re-install
```bash
mount -o subvol=root,compress=zstd /dev/mapper/enc /mnt
mkdir -p /mnt/{nix,persistent,boot}
mount -o subvol=nix,compress=zstd,noatime /dev/mapper/enc /mnt/nix
mount -o subvol=persistent,compress=zstd /dev/mapper/enc /mnt/persistent
mount /dev/nvme0n1p1 /mnt/boot

cd /mnt/etc/nixos
nixos-install --flake .#nixos
```
