{ config, pkgs, lib, ... }:

{
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
  hardware.enableAllFirmware = true;
  hardware.cpu.intel.updateMicrocode = true;
  boot = {
    loader = {
        limine = {
        enable = true;
        efiSupport = true;
        maxGenerations = 10;
        secureBoot.enable = true;
    };
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
      "i915.enable_guc=3"
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

    initrd.systemd.enable = true;
    initrd.kernelModules = [ "nvme" "xhci_pci" "usbhid" "tpm_tis" "tpm_crb" ];
    initrd.luks.devices."luks-682ff252-aeba-4582-853d-ed17b92ec0fa" = {
    device = "/dev/nvme0n1p1"; # Your encrypted partition
    crypttabExtraOpts = [ "tpm2-device=auto"  "x-systemd.device-timeout=10s" ];
  };
    initrd.verbose = false;
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

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      vpl-gpu-rt
      intel-media-driver
      intel-compute-runtime
    ];
  };

  services = {
    resolved.enable = false;
    blocky = {
   enable = true;
    settings = {
    # Port where Blocky listens for your local devices
    ports.dns = 53;

    bootstrapDns = {
      upstream = "https://cloudflare-dns.com/dns-query";
      ips = [ "1.1.1.1" ];
    };

    upstreams = {
      # Defining DoT providers
      groups.default = [
        "https://cloudflare-dns.com/dns-query"
        "https://dns.quad9.net/dns-query"
      ];
      # 'parallel_best' sends queries to all upstreams and takes the fastest reply
      strategy = "parallel_best";
    };

    # Caching configuration for speed
    caching = {
      minTime = "2h";      # Keep even short-lived records for 2 hours
      maxTime = "12h";
      prefetching = true;  # Refresh popular domains before they expire
    };

    # Optional: Add ad-blocking since you're using Blocky anyway
    blocking = {
      blockType = "zeroIp";
      denylists = {
        ads = [ "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" ];
      };
      clientGroupsBlock = {
        default = [ "ads" ];
      };
    };
  };
  };
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

    # 3. Security: Prevent DNS Bypassing (Your DoH protection)
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
      settings.pinentry-program =
        lib.mkForce "${pkgs.pinentry-curses}/bin/pinentry-curses";
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

    programs.nushell = {
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
          git push origin main
        }

        $env.SSH_AUTH_SOCK = $"/run/user/(id -u)/gcr/ssh"
        $env.GPG_TTY = (tty)
        gpg-connect-agent updatestartuptty /bye | ignore

        def ubuntu [] {
          podman run --rm -it -v $"($env.PWD):/data" -w /data ubuntu:latest bash
        }

        def sync-vault [] {
          let vault_path = ("~/obsidianVault" | path expand)
          let timestamp = (date now | format date "%Y-%m-%d %H:%M:%S")

        try {
          print $"(ansi b)--- Syncing with Git ---(ansi reset)"
          cd $vault_path
          git pull --rebase
          git add .
          git commit -m $"Vault Update: ($timestamp)"
          git push
        } catch {
           print $"(ansi r)--- Git Sync Failed! ---(ansi reset)"
        }    
}
      '';

      shellAliases = {
        #ls = "eza --icons";
        #ll = "eza -l --icons --git";
      };
    };

    programs.starship = { enable = true; enableNushellIntegration = true; };
    programs.zoxide = { enable = true; enableNushellIntegration = true; };
    programs.atuin = { enable = true; enableNushellIntegration = true; flags = []; };
    programs.fzf.enable = true;
    programs.zellij.enable = true;
    programs.carapace = {
      enable = true;
      enableNushellIntegration = true;
    };

    xdg.configFile."ghostty/config".text = ''
      theme = catppuccin-mocha
      font-family = "JetBrainsMono Nerd Font"
      font-size = 12
      command = nu
    '';
  };
}
