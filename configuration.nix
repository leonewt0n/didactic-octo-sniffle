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
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      grub.useOSProber = true;
      timeout = 0;
    };
    kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = [
      "quiet"
      "zswap.enabled=1"
      "zswap.compressor=zstd"
      "zswap.zpool=zsmalloc"
      "usbcore.autosuspend=-1"
      "i915.enable_guc=3"
          ];

    kernel.sysctl = {
      "kernel.split_lock_mitigate" = 0;
      "kernel.nmi_watchdog" = 0;
      "vm.swappiness" = 100;
      "vm.max_map_count" = 2147483642;
    };

    initrd.systemd.enable = true;
    initrd.verbose = false;
    plymouth.enable = true;
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
    displayManager.autoLogin = {
      enable = true;
      user = "nix";
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
    networkmanager.enable = false;
    wireless.enable = lib.mkForce false;
  };

  systemd = {
    network.enable = true;
    services.ModemManager.enable = false;
  };

  time.timeZone = "America/Los_Angeles";

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
      '';

      shellAliases = {
        ls = "eza --icons";
        ll = "eza -l --icons --git";
      };
    };

    programs.starship = { enable = true; enableNushellIntegration = true; };
    programs.zoxide = { enable = true; enableNushellIntegration = true; };
    programs.atuin = { enable = true; enableNushellIntegration = true; flags = []; };
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
}
