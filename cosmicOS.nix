{
  description = "Base Template for CosmicOS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    lanzaboote = { url = "github:nix-community/lanzaboote/v1.0.0"; inputs.nixpkgs.follows = "nixpkgs"; };
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    home-manager = { url = "github:nix-community/home-manager"; inputs.nixpkgs.follows = "nixpkgs"; };
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
          home-manager = { useGlobalPkgs = true; useUserPackages = true; extraSpecialArgs = { inherit inputs; }; };
        }
        ({ pkgs, lib, ... }: {
          imports = [ ./hardware-configuration.nix ];
          system.stateVersion = "26.05";
          nixpkgs.config.allowUnfree = true;

          nix.settings = { auto-optimise-store = true; eval-cores = 0; http-connections = 50; max-jobs = "auto"; };

          hardware = {
            enableAllFirmware = true;
            cpu.intel.updateMicrocode = true;
            graphics = {
              enable = true; enable32Bit = true;
              extraPackages = with pkgs; [ intel-compute-runtime intel-media-driver vpl-gpu-rt amdgpu open-nvidia ];
            };
          };
          boot = {
            consoleLogLevel = 0;
            kernelPackages = pkgs.linuxPackages_latest;
            lanzaboote = { enable = true; autoEnrollKeys.enable = true; pkiBundle = "/var/lib/sbctl"; };
            loader = { systemd-boot.enable = lib.mkForce false; timeout = 2; };
            kernelParams = [ 
              "8250.nr_uarts=0"  "quiet" "rd.systemd.show_status=false" 
              "rd.tpm2.wait-for-device=1" "tpm_tis.interrupts=0" "usbcore.autosuspend=-1" 
              " "zswap.compressor=zstd" "zswap.enabled=1" "zswap.zpool=zsmalloc" 
            ];
            kernel.sysctl = { "kernel.nmi_watchdog" = 0; "kernel.split_lock_mitigate" = 0; "vm.max_map_count" = 2147483642; "vm.swappiness" = 100; };
            initrd = {
              systemd.enable = true;
              kernelModules = [ "nvme" "xhci_pci" "usbhid" "tpm_tis" "tpm_crb" ];
            };
          };

          fileSystems = {
            "/" = { fsType = "btrfs"; options = [ "subvol=root" "compress=zstd" ]; };
            "/nix" = { fsType = "btrfs"; options = [ "subvol=nix" "compress=zstd" ]; };
            "/persistent" = { fsType = "btrfs"; neededForBoot = true; options = [ "subvol=persistent" "compress=zstd" ]; };
          };
          swapDevices = [{ device = "/swapfile"; size = 16384; priority = 10; }];

          networking = {
            hostName = "nixos"; ;  
            nameservers = [ "127.0.0.1" ];
            firewall = { enable = true; trustedInterfaces = [ "tailscale0" ]; allowedUDPPorts = [ 41641 ]; };
          };

          services = {
            tailscale.enable = true; flatpak.enable = true; fwupd.enable = true;
            resolved.enable = false; automatic-timezoned.enable = true;
            pipewire = { enable = true; alsa.enable = true; alsa.support32Bit = true; pulse.enable = true; };
            displayManager.cosmic-greeter.enable = true; desktopManager.cosmic.enable = true;
            blocky = {
              enable = true;
              settings = {
                ports.dns ="127.0.0.1:53"; bootstrapDns = { upstream = "https://cloudflare-dns.com/dns-query"; ips = [ "1.1.1.1" ]; };
                upstreams = { groups.default = [ "https://cloudflare-dns.com/dns-query" "https://dns.quad9.net/dns-query" ]; strategy = "parallel_best"; };
                caching = { minTime = "2h"; maxTime = "12h"; prefetching = true; };
                blocking = { blockType = "zeroIp"; denylists.ads = [ "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" ]; clientGroupsBlock.default = [ "ads" ]; };
              };
            };
          };

          virtualisation = { containers.enable = true; podman = { enable = true; dockerCompat = true; defaultNetwork.settings.dns_enabled = true; }; };

          fonts = { 
            enableDefaultPackages = true; packages = with pkgs; [ jetbrains-mono nerd-fonts.jetbrains-mono ];
            fontconfig.defaultFonts.monospace = [ "JetBrainsMono" ];
          };

          documentation.nixos.enable = false;

          users.users.root.hashedPassword = "!";
          users.users.nix = {
            isNormalUser = true; shell = pkgs.nushell; description = "nix user"; extraGroups = [ "wheel" "video" "seat" "audio" ];
          };

          home-manager.users.nix = { pkgs, ... }: {
            home.stateVersion = "26.05";
            manual = { manpages.enable = false; html.enable = false; json.enable = false; };
            home.packages = with pkgs; [ atuin carapace fzf helix starship zellij zoxide ];

            programs = {
              starship = { enable = true; enableNushellIntegration = true; };
              zoxide = { enable = true; enableNushellIntegration = true; };
              atuin = { enable = true; enableNushellIntegration = true; };
              carapace = { enable = true; enableNushellIntegration = true; };
              fzf.enable = true; zellij.enable = true;
              nushell = {
                enable = true;
                configFile.text = ''
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
