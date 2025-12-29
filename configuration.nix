{ config, pkgs, lib, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

 
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree         = true;

  ####################
  # Boot & Kernel    #
  ####################
  boot.loader.systemd-boot.enable      = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout                  = 0;
  boot.loader.limine.maxGenerations    = 5;
  #hardware.amdgpu.initrd.enable = false;

  boot.kernelParams = [ "quiet" ];
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernel.sysctl = {
    "kernel.split_lock_mitigate" = 0;
    "kernel.nmi_watchdog"        = 0;
    #"kernel.sched_bore"          = "1";
  };

  boot.initrd = {
    systemd.enable   = true;
    kernelModules    = [ ];
    verbose          = false;
  };
  boot.plymouth.enable     = true;
  boot.consoleLogLevel     = 0;
  systemd.settings.Manager = {DefaultTimeoutStopSec="5s";};

  #Determinate Linux

  
  ################
  # FileSystems  #
  ################
  fileSystems."/" = {
    options = [ "compress=zstd" ];
  };

  ############
  # Network  #
  ############
  networking = {
    networkmanager.enable = true;
    firewall.enable       = false;
    hostName              = "nixos";
  };

  
  #################
  # Sound & RTKit #
  #################
  security.rtkit.enable = true;
  services.pipewire = {
    enable         = true;
    alsa.enable    = true;
    alsa.support32Bit = true;
    pulse.enable   = true;
  };

  ########################
  # Desktop   #
  ########################
  services.displayManager.cosmic-greeter.enable = true;
  services.desktopManager.cosmic.enable = true;


  ########################
  # Programs & Services    #
  ########################
  services.automatic-timezoned.enable = true;
  zramSwap.enable = true;
  zramSwap.algorithm = "zstd";
  services.flatpak.enable = true;
  services.fwupd.enable = true;
  documentation.nixos.enable = false;  
  environment.systemPackages = [
    pkgs.helix
    pkgs.btop
    pkgs.ghostty
    pkgs.git
    pkgs.gh
    pkgs.fish
    pkgs.dua
    pkgs.bat
    pkgs.lsd
    pkgs.zoxide
  ];
  
  
  programs = {
    appimage = { enable = true; binfmt = true; };
    fish     = { enable = true; };
    mosh     = { enable = true; };
    tmux     = { enable = true; };
     };

  environment.sessionVariables = {
    PROTON_USE_NTSYNC       = "1";
    ENABLE_HDR_WSI          = "1";
    DXVK_HDR                = "1";
    PROTON_ENABLE_AMD_AGS   = "1";
    PROTON_ENABLE_NVAPI     = "1";
    ENABLE_GAMESCOPE_WSI    = "1";
    STEAM_MULTIPLE_XWAYLANDS = "1";
  };

  ###################
  # Virtualization  #
  ###################
  virtualisation.docker.enable      = true;
  virtualisation.docker.enableOnBoot = false;
  virtualisation.libvirtd.enable = true;

  ###############
  # Users       #
  ###############
  users.users.nix = {
    isNormalUser = true;
    shell = pkgs.fish;
    description  = "nix user";
    extraGroups  = [ "networkmanager" "wheel" "docker" "video" "seat" "audio" "libvirtd"];
  };

  #################
  # Security      #
  #################
  #security.sudo.wheelNeedsPassword = false;
  security.polkit.enable           = true;
  #services.seatd.enable            = true;
  #services.openssh.enable          = true;

  ######################
  ######################

  ########################
  # System State Version #
  ########################
  system.stateVersion = "26.05";
}
