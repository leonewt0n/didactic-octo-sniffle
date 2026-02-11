{
  description = "NixOS Unstable Configuration with Determinate Nix";

  inputs = {
    # 1. Use the latest unstable Nix packages
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    #nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0";
    

    # 2. Determinate Systems Flake (Improved Nix settings, caching, daemon)
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";

    # 3. Home Manager (must match nixpkgs version)
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, determinate, ... }@inputs: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; }; # Pass inputs to modules
      modules = [
        # Your main configuration file
        ./configuration.nix
        
        # The Determinate Nix module (Enables Flakes, Determinate Caching, etc.)
        determinate.nixosModules.default

        # Home Manager Module (Replaces <home-manager/nixos>)
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          
          # Pass inputs to home-manager modules so you can use them there too
          home-manager.extraSpecialArgs = { inherit inputs; };
        }
      ];
    };
  };
}
