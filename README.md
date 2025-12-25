# didactic-octo-sniffle

https://nix-community.github.io/lanzaboote/getting-started/prepare-your-system.html

# MAKE SURE YOUR USING THE RIGHT PARTITION!
``
sudo systemd-cryptenroll --tpm2-with-pin=yes --tpm2-device=auto --tpm2-pcrs=0+2+7+12 --wipe-slot=tpm2 /dev/nvme0n1p2
``
