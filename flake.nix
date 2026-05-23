{
  description = "NixOS Homelab Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    agenix.url = "github:ryantm/agenix";
  };

  outputs = { self, nixpkgs, agenix }: {
    nixosConfigurations.nix-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { agenixPkgs = agenix.packages.x86_64-linux; };
      modules = [
        ./configuration.nix
        agenix.nixosModules.default
      ];
    };
  };
}