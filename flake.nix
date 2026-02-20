{
  description = "Intel 265K System with Intel GPU + Lanzaboote Secureboot w/ TPM LUKS unlock";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    lanzaboote = { url = "github:nix-community/lanzaboote/v1.0.0"; inputs.nixpkgs.follows = "nixpkgs"; };
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    home-manager = { url = "github:nix-community/home-manager"; inputs.nixpkgs.follows = "nixpkgs"; };
    impermanence.url = "github:nix-community/impermanence";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, lanzaboote, determinate, disko, impermanence, ... } @ inputs: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        disko.nixosModules.disko
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
              extraPackages = with pkgs; [ intel-compute-runtime intel-media-driver vpl-gpu-rt ];
            };
          };

          boot = {
            consoleLogLevel = 0; plymouth.enable = true;
            kernelPackages = pkgs.linuxPackages_latest;
            lanzaboote = { enable = true; autoEnrollKeys.enable = true;autoGenerateKeys.enable = true; pkiBundle = "/var/lib/sbctl"; };
            loader = { systemd-boot.enable = lib.mkForce false; timeout = 0; };
            kernelParams = [ 
              "8250.nr_uarts=0" "i915.force_probe=!7d67" "quiet" "rd.systemd.show_status=false" 
              "rd.tpm2.wait-for-device=1" "tpm_tis.interrupts=0" "usbcore.autosuspend=-1" 
              "xe.force_probe=7d67" "zswap.compressor=zstd" "zswap.enabled=1" "zswap.zpool=zsmalloc" 
            ];
            kernel.sysctl = { "kernel.split_lock_mitigate" = 0; "vm.max_map_count" = 2147483642; "vm.swappiness" = 100; };
            initrd = {
              systemd.enable = true;
              kernelModules = [ "nvme" "xhci_pci" "usbhid" "tpm_tis" "tpm_crb" ];
              systemd.services.rollback = {
                description = "Rollback BTRFS root subvolume";
                wantedBy = [ "initrd.target" ]; after = [ "systemd-cryptsetup@enc.service" ]; before = [ "sysroot.mount" ];
                unitConfig.DefaultDependencies = "no"; serviceConfig.Type = "oneshot";
                script = ''
                  mkdir -p /mnt
                  mount -o subvol=/ /dev/mapper/enc /mnt
                  btrfs subvolume list -o /mnt/root | cut -f9 -d' ' | while read sub; do btrfs subvolume delete "/mnt/$sub"; done
                  btrfs subvolume delete /mnt/root
                  btrfs subvolume snapshot /mnt/root-blank /mnt/root
                  umount /mnt
                '';
              };
            };
          };
          fileSystems = {
            "/" = { fsType = "btrfs"; options = [ "subvol=root" "compress=zstd" ]; };
            "/nix" = { fsType = "btrfs"; options = [ "subvol=nix" "compress=zstd" ]; };
            "/persistent" = { fsType = "btrfs"; neededForBoot = true; options = [ "subvol=persistent" "compress=zstd" ]; };
          };

          environment.persistence."/persistent" = {
            hideMounts = true;
            directories = [ "/var/lib/"  "/var/log" ];
            files = [ "/etc/machine-id" ];
          };

          swapDevices = [{ device = "/swapfile"; size = 16384; priority = 10; }];

          networking = {
            hostName = "nixos"; 
            nameservers = [ "127.0.0.1" ];
            firewall = { enable = true; trustedInterfaces = [ "tailscale0" ]; allowedUDPPorts = [ 41641 ]; };
          };

          security.pam.services = { login.u2fAuth = true; sudo.u2fAuth = true; };
          security.pam.u2f = { enable = true; control = "sufficient"; settings.cue = true; };

          services = {
            tailscale.enable = true; flatpak.enable = true; fwupd.enable = true; tzupdate.enable = true; system76-scheduler.enable = true;
            resolved.enable = false;pipewire = { enable = true; alsa.enable = true; alsa.support32Bit = true; pulse.enable = true; };
            displayManager.cosmic-greeter.enable = true; desktopManager.cosmic.enable = true;
            unbound = {enable = true;settings = {server = {interface = [ "127.0.0.1" ];prefetch = "yes";access-control = [ "127.0.0.0/8 allow" ];};forward-zone = [{name = ".";forward-tls-upstream = "yes";forward-addr = [
            "1.1.1.1@853#cloudflare-dns.com" "1.0.0.1@853#cloudflare-dns.com"];}];};};
          };

          virtualisation = { containers.enable = true; podman = { enable = true; dockerCompat = true; defaultNetwork.settings.dns_enabled = true; }; };

          environment.systemPackages = with pkgs; [busybox toybox git-remote-gcrypt gnupg pinentry-curses sbctl ];
          fonts = { 
            enableDefaultPackages = true; packages = with pkgs; [ jetbrains-mono nerd-fonts.jetbrains-mono ];
            fontconfig.defaultFonts.monospace = [ "JetBrainsMono" ];
          };

          programs = {
            appimage = {enable = true; binfmt = true;};
            nix-ld.enable = true;
            gnupg.agent = { enable = true; enableSSHSupport = false; pinentryPackage = pkgs.pinentry-curses; settings.pinentry-program = lib.mkForce "${pkgs.pinentry-curses}/bin/pinentry-curses"; };
          };

          documentation.nixos.enable = false;
         
          users.mutableUsers = false;
          users.users.root.hashedPassword = "!";
          users.users.nix = {
            isNormalUser = true; shell = pkgs.nushell; description = "nix user"; extraGroups = [ "wheel" "video" "render" "seat" "audio" ];
            hashedPassword = "$6$FA0MUKHblWK2Ym8O$aQx3otoJ2hYTDA2kyfhEdPFm5gJQgg/LUJ3GBOmr4/A2MtTwPUWd/ZlFlutCInhN7s7T/51fwWRGiJiM07R2r1";
          };

          home-manager.users.nix = { pkgs, ... }: {
            home.stateVersion = "26.05";
            manual = { manpages.enable = false; html.enable = false; json.enable = false; };
            home.packages = with pkgs; [ atuin btop carapace fzf helix starship zellij zoxide ];
            systemd.user.services.kickstart-blocky = {
              Unit = { Description = "One-time Blocky restart on login"; After = [ "graphical-session.target" ]; };
              Service = { Type = "oneshot"; ExecStart = "${pkgs.sudo}/bin/sudo ${pkgs.systemd}/bin/systemctl restart blocky.service"; RemainAfterExit = true; };
              install.wantedBy = [ "graphical-session.target" ];
            };
            home.persistence."/persistent" = {
              directories = [ 
                ".config" ".gnupg" ".local/share"  ".ssh"  ".var" "ROMs" "Archive" "Documents" "Downloads" "DOS" "git" "obsidianVault" "Pictures" "Videos" 
              ];
              files = [ ".bashrc" ];
            };
            programs = {
              git = { enable = true; settings.user = { name = "Leo Newton"; email = "leo253@pm.me"; }; settings.init.defaultBranch = "main"; };
              starship = { enable = true; enableNushellIntegration = true; };
              zoxide = { enable = true; enableNushellIntegration = true; };
              atuin = { enable = true; enableNushellIntegration = true; };
              carapace = { enable = true; enableNushellIntegration = true; };
              fzf.enable = true; zellij.enable = true;
              nushell = {
                enable = true;
                configFile.text = ''
                  $env.config = { show_banner: false, edit_mode: vi }
                  def update [] { sudo cp -r ~/git/nixos/* /etc/nixos/; sudo nix flake update --flake /etc/nixos/; sudo nixos-rebuild switch --flake /etc/nixos/ }
                  def push [msg?: string] {
                    $env.GPG_TTY = (tty); gpg-connect-agent updatestartuptty /bye | ignore; git add -A
                    let m = if ($msg | is-empty) { (date now | format date '%Y-%m-%d %H:%M:%S') } else { $msg }; git commit -m $m; git push
                  }
                  $env.SSH_AUTH_SOCK = $"/run/user/(id -u)/gcr/ssh"; $env.GPG_TTY = (tty); gpg-connect-agent updatestartuptty /bye | ignore
                  def ubuntu [] { podman run --rm -it -v $"($env.PWD):/data" -w /data ubuntu:latest bash }
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
