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

```
sudo systemd-cryptenroll --wipe-slot=tpm2 /dev/nvme0n1p1
sudo systemd-cryptenroll /dev/nvme0n1p1 --tpm2-device=auto --tpm2-pcrs=0+2+7
```
# TODO: Setup Impermence when we have more RAM
https://wiki.nixos.org/wiki/Impermanence


https://nix-community.github.io/lanzaboote/getting-started/prepare-your-system.html
https://haseebmajid.dev/posts/2025-12-31-how-to-setup-a-new-pc-with-lanzaboote-tpm-decryption-sops-nix-impermanence-nixos-anywhere/
