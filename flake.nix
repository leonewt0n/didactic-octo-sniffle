{
  description = "Intel 265K System with Intel GPU + Lanzaboote Secureboot w/ TPM LUKS unlock";

  inputs = {
    # 1. Use the latest unstable Nix packages
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Lanzaboote for Secure Boot support
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.0.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # 2. Determinate Systems Flake (Improved Nix settings, caching, daemon)
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";

    # 3. Home Manager (must match nixpkgs version)
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # 4. Impermanence
    impermanence.url = "github:nix-community/impermanence";
  };

  outputs = { self, nixpkgs, home-manager, lanzaboote, determinate, impermanence, ... } @ inputs: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      
      modules = [
        lanzaboote.nixosModules.lanzaboote
        determinate.nixosModules.default
        home-manager.nixosModules.home-manager
        impermanence.nixosModules.impermanence

        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = { inherit inputs; };
        }

        # --- Main System Configuration ---
        ({ pkgs, lib, ... }: {
          imports = [ ./hardware-configuration.nix ];

          system.stateVersion = "26.05";
          nixpkgs.config.allowUnfree = true;

          # --- Nix Settings ---
          nix.settings = {
            auto-optimise-store = true;
            eval-cores = 0;
            http-connections = 50;
            max-jobs = "auto";
          };

          # --- Hardware & Graphics ---
          hardware = {
            enableAllFirmware = true;
            cpu.intel.updateMicrocode = true;
            graphics = {
              enable = true;
              enable32Bit = true;
              extraPackages = with pkgs; [
                intel-compute-runtime
                intel-media-driver
                vpl-gpu-rt
              ];
            };
          };

          # --- Bootloader & Kernel ---
          boot = {
            consoleLogLevel = 0;
            kernelPackages = pkgs.linuxPackages_latest;
            
            lanzaboote = {
              enable = true;
              autoEnrollKeys.enable = true;
              pkiBundle = "/var/lib/sbctl";
            };

            loader = {
              systemd-boot.enable = lib.mkForce false;
              timeout = 2;
            };

            kernelParams = [
              "8250.nr_uarts=0"
              "i915.force_probe=!7d67"
              "quiet"
              "rd.systemd.show_status=false"
              "rd.tpm2.wait-for-device=1"
              "tpm_tis.interrupts=0"
              "usbcore.autosuspend=-1"
              "xe.force_probe=7d67"
              "zswap.compressor=zstd"
              "zswap.enabled=1"
              "zswap.zpool=zsmalloc"
            ];

            kernel.sysctl = {
              "kernel.nmi_watchdog" = 0;
              "kernel.split_lock_mitigate" = 0;
              "vm.max_map_count" = 2147483642;
              "vm.swappiness" = 100;
            };

            initrd = {
              systemd.enable = true;
              kernelModules = [ "nvme" "xhci_pci" "usbhid" "tpm_tis" "tpm_crb" ];
              verbose = false;

              systemd.services.rollback = {
                description = "Rollback BTRFS root subvolume to a pristine state";
                wantedBy = [ "initrd.target" ];
                after = [ "systemd-cryptsetup@enc.service" ]; # LUKS/TPM process
                before = [ "sysroot.mount" ];
                unitConfig.DefaultDependencies = "no";
                serviceConfig.Type = "oneshot";
                script = ''
                  mkdir -p /mnt
                  # We first mount the btrfs root to /mnt so we can manipulate btrfs subvolumes.
                  mount -o subvol=/ /dev/mapper/enc /mnt
                  
                  # While we're tempted to just delete /root and create a new snapshot from /root-blank, 
                  # /root is already populated at this point with a number of subvolumes, which makes 
                  # `btrfs subvolume delete` fail.
                  # So, we remove them first.
                  #
                  # /root contains subvolumes:
                  # - /root/var/lib/portables
                  # - /root/var/lib/machines
                  #
                  # I suspect these are related to systemd-nspawn, but since I don't use it I'm not 100% sure.
                  # Anyhow, deleting these subvolumes hasn't resulted in any issues so far, 
                  # except for fairly benign-looking errors from systemd-tmpfiles.

                  btrfs subvolume list -o /mnt/root | cut -f9 -d' ' | while read subvolume; do
                    echo "deleting /$subvolume subvolume..."
                    btrfs subvolume delete "/mnt/$subvolume"
                  done &&
                  echo "deleting /root subvolume..." &&
                  btrfs subvolume delete /mnt/root
                  
                  echo "restoring blank /root subvolume..."
                  btrfs subvolume snapshot /mnt/root-blank /mnt/root
                  
                  # Once we're done rolling back to a blank snapshot, we can unmount /mnt and continue on the boot process.
                  umount /mnt
                '';
              };
            };
          };

          # --- Storage & Persistence ---
          fileSystems = {
            "/" = { fsType = "btrfs"; options = [ "subvol=root" "compress=zstd" ]; };
            "/nix" = { fsType = "btrfs"; options = [ "subvol=nix" "compress=zstd" ]; };
            "/persistent" = {
              fsType = "btrfs";
              neededForBoot = true;
              options = [ "subvol=persistent" "compress=zstd" ];
            };
          };

          environment.persistence."/persistent" = {
            hideMounts = true;
            directories = [
              "/var/lib/nixos"
              "/var/lib/sbctl"
              "/var/lib/systemd/coredump"
              "/var/log"
            ];
            files = [ "/etc/machine-id" ];
          };

          swapDevices = [{
            device = "/swapfile";
            size = 16384;
            priority = 10;
          }];

          # --- Networking & Security ---
          networking = {
            hostName = "nixos";
            useNetworkd = true;
            networkmanager.enable = false;
            wireless.enable = lib.mkForce false;
            nameservers = [ "127.0.0.1" ];
            firewall = {
              enable = true;
              trustedInterfaces = [ "tailscale0" ];
              allowedUDPPorts = [ 41641 ];
              extraCommands = ''
                # Allow local lookups to your Blocky instance
                iptables -A OUTPUT -d 127.0.0.1 -p udp --dport 53 -j ACCEPT
                iptables -A OUTPUT -d 127.0.0.1 -p tcp --dport 53 -j ACCEPT

                # BLOCK all other outgoing DNS to prevent apps from bypassing Blocky
                iptables -A OUTPUT -p udp --dport 53 -j REJECT
                iptables -A OUTPUT -p tcp --dport 53 -j REJECT
                iptables -A OUTPUT -p tcp --dport 853 -j REJECT
              '';
            };
          };

          security.pam.services = {
            login.u2fAuth = true;
            sudo.u2fAuth = true;
          };

          security.pam.u2f = {
            enable = true;
            control = "sufficient"; # Use "sufficient" if you want password OR key
            settings = {
              cue = true; # Tells the system to prompt you to "touch your device"
            };
          };

          services = {
            # Core Services
            tailscale.enable = true;
            flatpak.enable = true;
            fwupd.enable = true;
            resolved.enable = false;
            avahi.enable = false;
            printing.enable = false;
            geoclue2.enable = lib.mkForce false;
            automatic-timezoned.enable = false;

            # Media & Desktop
            pipewire = {
              enable = true;
              alsa.enable = true;
              alsa.support32Bit = true;
              pulse.enable = true;
            };
            displayManager.cosmic-greeter.enable = true;
            desktopManager.cosmic.enable = true;

            # DNS Blocking
            blocky = {
              enable = true;
              settings = {
                ports.dns = 53;
                bootstrapDns = {
                  upstream = "https://cloudflare-dns.com/dns-query";
                  ips = [ "1.1.1.1" ];
                };
                upstreams = {
                  groups.default = [
                    "https://cloudflare-dns.com/dns-query"
                    "https://dns.quad9.net/dns-query"
                  ];
                  strategy = "parallel_best";
                };
                caching = {
                  minTime = "2h";
                  maxTime = "12h";
                  prefetching = true;
                };
                blocking = {
                  blockType = "zeroIp";
                  denylists.ads = [ "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" ];
                  clientGroupsBlock.default = [ "ads" ];
                };
              };
            };
          };

          # --- Virtualization ---
          virtualisation = {
            containers.enable = true;
            podman = {
              enable = true;
              dockerCompat = true;
              defaultNetwork.settings.dns_enabled = true;
            };
          };

          # --- System Packages & Fonts ---
          environment.systemPackages = with pkgs; [
            btop
            git
            git-remote-gcrypt
            gnupg
            pinentry-curses
            sbctl
          ];

          fonts = {
            enableDefaultPackages = true;
            packages = with pkgs; [
              jetbrains-mono
              nerd-fonts.jetbrains-mono
            ];
            fontconfig.defaultFonts.monospace = [ "JetBrainsMono" ];
          };

          # --- Programs ---
          programs = {
            mosh.enable = true;
            steam.enable = true;
            gnupg.agent = {
              enable = true;
              enableSSHSupport = false;
              pinentryPackage = pkgs.pinentry-curses;
              settings.pinentry-program = lib.mkForce "${pkgs.pinentry-curses}/bin/pinentry-curses";
            };
          };

          systemd = {
            network.enable = true;
            services.ModemManager.enable = false;
          };

          time.timeZone = "America/Los_Angeles";
          documentation.nixos.enable = false;

          # --- Users ---
          users.mutableUsers = false;
          users.users.root.hashedPassword = "!"; # Locks account
          users.users.nix = {
            isNormalUser = true;
            shell = pkgs.nushell;
            description = "nix user";
            extraGroups = [ "wheel" "video" "seat" "audio" ];
            hashedPassword = "$6$FA0MUKHblWK2Ym8O$aQx3otoJ2hYTDA2kyfhEdPFm5gJQgg/LUJ3GBOmr4/A2MtTwPUWd/ZlFlutCInhN7s7T/51fwWRGiJiM07R2r1";
          };

          # --- Home Manager Config ---
          home-manager.users.nix = { pkgs, ... }: {
            home.stateVersion = "26.05";
            manual = {
              manpages.enable = false;
              html.enable = false;
              json.enable = false;
            };

            home.packages = with pkgs; [
              atuin
              carapace
              fzf
              helix
              starship
              zellij
              zoxide
            ];

            home.persistence."/persistent" = {
              directories = [
                ".config"
                ".gnupg"
                ".local/share/flatpak"
                ".local/Steam"
                ".ssh"
                ".steam"
                ".var"
                ".var/app"
                "Archive"
                "Documents"
                "Downloads"
                "DOS"
                "git"
                "obsidianVault"
                "Pictures"
                "Videos"
              ];
              files = [ ".bashrc" ];
            };

            programs = {
              starship = { enable = true; enableNushellIntegration = true; };
              zoxide = { enable = true; enableNushellIntegration = true; };
              atuin = { enable = true; enableNushellIntegration = true; };
              carapace = { enable = true; enableNushellIntegration = true; };
              fzf.enable = true;
              zellij.enable = true;

              nushell = {
                enable = true;
                configFile.text = ''
                  $env.config = {
                    show_banner: false
                    edit_mode: vi
                  }

                  def update [] {
                    sudo nix flake update --flake /etc/nixos/
                    sudo nixos-rebuild switch --flake /etc/nixos/
                  }

                  def push [message?: string] {
                    $env.GPG_TTY = (tty)
                    gpg-connect-agent updatestartuptty /bye | ignore
                    git add -A
                    let commit_msg = if ($message | is-empty) {
                      $"(date now | format date '%Y-%m-%d %H:%M:%S')"
                    } else {
                      $message
                    }
                    git commit -m $commit_msg
                    git push 
                  }

                  $env.SSH_AUTH_SOCK = $"/run/user/(id -u)/gcr/ssh"
                  $env.GPG_TTY = (tty)
                  gpg-connect-agent updatestartuptty /bye | ignore

                  def ubuntu [] {
                    podman run --rm -it -v $"($env.PWD):/data" -w /data ubuntu:latest bash
                  }
                '';
                shellAliases = {};
              };
            };
          };
        })
      ];
    };
  };
}
