# NixOS Pin TPM LUKS with Lanzaboote Secure Boot

https://nix-community.github.io/lanzaboote/getting-started/prepare-your-system.html

# MAKE SURE YOUR USING THE RIGHT PARTITION!
```
sudo systemd-cryptenroll --tpm2-with-pin=yes --tpm2-device=auto --tpm2-pcrs=0+2+7+12 --wipe-slot=tpm2 /dev/nvme0n1p2
```

On some systems, manually remove all keys and enroll efi in /efi/linux/ or /efi/nix/ folder to get it to boot then run command to enroll --microsoft.

# For Determinate Nix after boot

```
sudo nixos-rebuild \
  --option extra-substituters https://install.determinate.systems \
  --option extra-trusted-public-keys cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM= \
  --flake ... \
  switch
```
