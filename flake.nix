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

  outputs = {
    self,
    nixpkgs,
    home-manager,
    lanzaboote,
    determinate,
    impermanence,
    ...
  } @ inputs: {
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

        # Main System Configuration
        ({ pkgs, lib, ... }: {
          imports = [
            ./hardware-configuration.nix
          ];

          system.stateVersion = "26.05";
          nixpkgs.config.allowUnfree = true;

          nix.settings = {
            max-jobs = "auto";
            eval-cores = 0;
            http-connections = 50;
            auto-optimise-store = true;
          };

          hardware = {
            enableAllFirmware = true;
            cpu.intel.updateMicrocode = true;
            graphics = {
              enable = true;
              enable32Bit = true;
              extraPackages = with pkgs; [
                vpl-gpu-rt
                intel-media-driver
                intel-compute-runtime
              ];
            };
          };

          boot = {
            lanzaboote = {
              enable = true;
              pkiBundle = "/var/lib/sbctl";
              autoEnrollKeys.enable = true;
            };

            loader = {
              systemd-boot.enable = lib.mkForce false;
              timeout = 2;
            };

            kernelPackages = pkgs.linuxPackages_latest;
            kernelParams = [
              "quiet"
              "zswap.enabled=1"
              "zswap.compressor=zstd"
              "zswap.zpool=zsmalloc"
              "usbcore.autosuspend=-1"
              "i915.force_probe=!7d67"
              "xe.force_probe=7d67"
             # "i915.enable_guc=3"
              "8250.nr_uarts=0"
              "rd.systemd.show_status=false"
              "rd.tpm2.wait-for-device=1"
              "tpm_tis.interrupts=0"
            ];

            kernel.sysctl = {
              "kernel.split_lock_mitigate" = 0;
              "kernel.nmi_watchdog" = 0;
              "vm.swappiness" = 100;
              "vm.max_map_count" = 2147483642;
            };

            initrd = {
              systemd.enable = true;
              kernelModules = [ "nvme" "xhci_pci" "usbhid" "tpm_tis" "tpm_crb" ];
              verbose = false;
            };
            consoleLogLevel = 0;
          };

          fileSystems."/" = {
            options = [ "compress=zstd" ];
          };

          swapDevices = [{
            device = "/swapfile";
            size = 16384;
            priority = 10;
          }];

          services = {
            resolved.enable = false;
            pipewire = {
              enable = true;
              alsa.enable = true;
              alsa.support32Bit = true;
              pulse.enable = true;
            };

            displayManager.cosmic-greeter.enable = true;
            desktopManager.cosmic.enable = true;
            
            automatic-timezoned.enable = false;
            avahi.enable = false;
            printing.enable = false;
            geoclue2.enable = lib.mkForce false;
            tailscale.enable = true;
            flatpak.enable = true;
            fwupd.enable = true;

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

          networking = {
            hostName = "nixos";
            useNetworkd = true;
            nameservers = [ "127.0.0.1" ];
            networkmanager.enable = false;
            wireless.enable = lib.mkForce false;
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

          systemd = {
            network.enable = true;
            services.ModemManager.enable = false;
          };

          time.timeZone = "America/Los_Angeles";

          environment.systemPackages = with pkgs; [
            btop
            git
            gnupg
            git-remote-gcrypt
            pinentry-curses
            sbctl
          ];

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

          documentation.nixos.enable = false;

          virtualisation = {
            containers.enable = true;
            podman = {
              enable = true;
              dockerCompat = true;
              defaultNetwork.settings.dns_enabled = true;
            };
          };

          fonts = {
            enableDefaultPackages = true;
            packages = with pkgs; [
              jetbrains-mono
              nerd-fonts.jetbrains-mono
            ];
            fontconfig.defaultFonts.monospace = [ "JetBrainsMono" ];
          };

          users.users.nix = {
            isNormalUser = true;
            shell = pkgs.nushell;
            description = "nix user";
            extraGroups = [ "wheel" "video" "seat" "audio" ];
          };

          # Home Manager Config
          home-manager.users.nix = { pkgs, ... }: {
            home.stateVersion = "26.05";

            manual = {
              manpages.enable = false;
              html.enable = false;
              json.enable = false;
            };

            home.packages = with pkgs; [
              helix
              carapace
              zoxide
              atuin
              fzf
              starship
              zellij
            ];

            programs = {
              starship = {
                enable = true;
                enableNushellIntegration = true;
              };
              zoxide = {
                enable = true;
                enableNushellIntegration = true;
              };
              atuin = {
                enable = true;
                enableNushellIntegration = true;
              };
              fzf.enable = true;
              zellij.enable = true;
              carapace = {
                enable = true;
                enableNushellIntegration = true;
              };
              
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
                shellAliases = {
                  # ls = "eza --icons";
                };
              };
            };
          };
        })
      ];
    };
  };
}
