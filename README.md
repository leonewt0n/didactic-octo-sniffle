# Personal Config File for Intel 265K System with Intel GPU + Lanzaboote Secureboot w/ TPM LUKS unlock

This requires you to already have generated the keys and enrolled them with `sbctl`.

To create keys use `sbctl create-keys`.

```
nix-shell -p sbctl
sudo sbctl create-keys
```

To enroll them first reset secure boot to “Setup Mode”. This is device specific. Then enroll them using `sbctl enroll-keys -m -f`.

You can now rebuild your system with this option enabled.

Afterwards turn setup mode off and enable secure boot.

# Replace in the config file with your specific IDs
```
initrd.luks.devices."luks-682ff252-XXXX-XXXX-XXXX-XXXXXXX" = {
device = "/dev/nvme0n1pXX"; # Your encrypted partition
```
```
❯ : lsblk -f
NAME                         FSTYPE      FSVER LABEL     UUID                                 FSAVAIL FSUSE% MOUNTPOINTS
sda                          zfs_member  5000  boot-pool 13019466780310741369
├─sda1                       vfat        FAT32           E4C9-5557
├─sda2
├─sda3                       ntfs                        CC34CDA134CD8EC0
└─sda4                       ntfs                        E0F65007F64FDC82
nvme0n1
├─nvme0n1p1                  crypto_LUKS 2               682ff252-aeba-4582-853d-ed17b92ec0fa
│ ├─luks-682ff252-aeba-4582-853d-ed17b92ec0fa
│ │                          btrfs                       5de7dbab-adfd-40c1-9fea-df6656f3bb07    2.2T    40% /home
│ │                                                                                                          /nix/store
│ │                                                                                                          /
│ └─root                     btrfs                       5de7dbab-adfd-40c1-9fea-df6656f3bb07
└─nvme0n1p2                  vfat        FAT32           CCA5-9CFF                             631.4M    47% /boot

```

```
sudo systemd-cryptenroll --wipe-slot=tpm2 /dev/nvme0n1p1
sudo systemd-cryptenroll /dev/nvme0n1p2 \
    --wipe-slot=tpm2 \
    --tpm2-device=auto \
    --tpm2-pcrs=0+2+7 \
    --tpm2-pcrs=15:sha256=0000000000000000000000000000000000000000000000000000000000000000
```

https://nix-community.github.io/lanzaboote/getting-started/prepare-your-system.html
https://haseebmajid.dev/posts/2025-12-31-how-to-setup-a-new-pc-with-lanzaboote-tpm-decryption-sops-nix-impermanence-nixos-anywhere/
