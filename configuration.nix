{ config, pkgs, lib, ... }:

{
  imports = [ 
    ./hardware-configuration.nix
   # <home-manager/nixos>
  ];

  nixpkgs.config.allowUnfree = true;
  nix.settings = {
    # 2. Build Parallelism (Compiling packages)
    # "auto" sets it to the number of logical cores (Threads)
    max-jobs = "auto";
    eval-cores = 0;
    
    # 3. Download/Fetch Parallelism
    # Maximum number of parallel TCP connections for binary caches
    http-connections = 50;
    
    # 4. Store Optimization (Optional but recommended)
    # Deduplicates identical files in the store automatically
    auto-optimise-store = true;
  };

  ####################
  # Boot & Kernel    #
  ####################
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
    grub.useOSProber = true;
    timeout = 0;
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [ "quiet" "zswap.enabled=1" "zswap.compressor=zstd" "zswap.zpool=zsmalloc" "usbcore.autosuspend=-1" "i915.force_probe=!7d67" "enable_guc=3" "xe.force_probe=7d67" "xe.enable_psr=0" "pcie_aspm.policy=performance" "intel_idle.max_cstate=1" ];
   boot.kernel.sysctl = {
    "kernel.split_lock_mitigate" = 0;
    "kernel.nmi_watchdog" = 0;
    "vm.swappiness" = 100;
    "vm.max_map_count" = 2147483642;
  };

  boot.initrd = {
    systemd.enable = true;
    verbose = false;
  };

  boot.plymouth.enable = true;
  boot.consoleLogLevel = 0;

  ####################
  # Graphics & Sound #
  ####################
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      vpl-gpu-rt
      intel-media-driver 
      intel-compute-runtime
      #intel-gmmlib
    ];
  };

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  ####################
  # Desktop & System #
  ####################
  services.displayManager.cosmic-greeter.enable = true;
  services.desktopManager.cosmic.enable = true;
  services.automatic-timezoned.enable = true;
  # 2. Configure Auto-Login
  services.displayManager.autoLogin = {
    enable = true;
    user = "nix"; # Replace with your actual username
  };

  # 3. Ensure the session is set to COSMIC
  services.displayManager.defaultSession = "cosmic";
  
  networking = {
    networkmanager.enable = true;
    firewall.enable = true;
    hostName = "nixos";
  };

  fileSystems."/" = {
    options = [ "compress=zstd" ];
  };

  swapDevices = [ {
    device = "/swapfile";
    size = 16384; 
    priority = 10;
  } ];

  ####################
  # Programs (System)#
  ####################
  environment.systemPackages = with pkgs; [
    btop
    git
    gh
    dua
    bat
    lsd
    gnupg
    git-remote-gcrypt
    pinentry-curses
    podman-compose
    podman-tui
  ];

  programs = {
    appimage = { enable = true; binfmt = true; };
    mosh.enable = true;
    tmux.enable = true;
    steam.enable = true;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = false;
      pinentryPackage = pkgs.pinentry-curses;
      settings = {
      # Use mkForce to resolve the conflict with the internal NixOS module
      pinentry-program = lib.mkForce "${pkgs.pinentry-curses}/bin/pinentry-curses";
       };
    };
  };

  services.flatpak.enable = true;
  services.fwupd.enable = true;
  documentation.nixos.enable = false;
  ####################
  # Virtualization   #
  ####################
  virtualisation.containers.enable = true;
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  ####################
  # Fonts            #
  ####################
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      jetbrains-mono
      nerd-fonts.jetbrains-mono
    ];
    fontconfig.defaultFonts.monospace = [ "JetBrainsMono" ];
  };

  ####################
  # User Account     #
  ####################
  users.users.nix = {
    isNormalUser = true;
    shell = pkgs.nushell;
    description = "nix user";
    extraGroups = [ "networkmanager" "wheel" "video" "seat" "audio" ];
  };

  ####################
  # Home Manager     #
  ####################
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
      eza
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
        
        
        # --- Custom Functions from config.nu ---
        
        # A helper to sync your encrypted Obsidian vault
        def push [message?: string] {
            $env.GPG_TTY = (tty)
            gpg-connect-agent updatestartuptty /bye | ignore

            print "Staging changes..."
            git add -A

            let commit_msg = if ($message | is-empty) { 
                $"(date now | format date '%Y-%m-%d %H:%M:%S')" 
            } else { 
                $message 
            }

            print $"Committing: ($commit_msg)"
            git commit -m $commit_msg
            git push origin main
        }
        # Ensure GPG/SSH plumbing is correct on startup
        $env.SSH_AUTH_SOCK = $"/run/user/(id -u)/gcr/ssh"
        $env.GPG_TTY = (tty)
        # Refresh the agent's TTY mapping on every new shell start
        gpg-connect-agent updatestartuptty /bye | ignore

        
        # Quick Ubuntu container environment
        def ubuntu [] {
            podman run --rm -it -v $"($env.PWD):/data" -w /data ubuntu:latest bash
        }
      '';
      shellAliases = {
        ls = "eza --icons";
        ll = "eza -l --icons --git";
      };
    };

    # Shell and CLI tool integrations
    programs.starship = { enable = true; enableNushellIntegration = true; };
    programs.zoxide = { enable = true; enableNushellIntegration = true; };
    programs.atuin = { enable = true; enableNushellIntegration = true; flags = [  ]; };
    
    # fzf integration is handled automatically or manually in Nushell config
    programs.fzf.enable = true; 
    
    programs.eza = { enable = true; enableNushellIntegration = true; };
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

  system.stateVersion = "26.05";
}
