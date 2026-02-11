# Personal Config File for Intel 265K System with Intel GPU + limine Secureboot w/ TPM LUKS unlock

This requires you to already have generated the keys and enrolled them with `sbctl`.

To create keys use `sbctl create-keys`.

```
nix-shell -p sbctl
sudo sbctl create-keys
```

To enroll them first reset secure boot to “Setup Mode”. This is device specific. Then enroll them using `sbctl enroll-keys -m -f`.

You can now rebuild your system with this option enabled.

Afterwards turn setup mode off and enable secure boot.

```
lsblk
sudo systemd-cryptenroll --wipe-slot=tpm2 /dev/nvme0n1p1
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+7 /dev/nvme0n1p1

```
