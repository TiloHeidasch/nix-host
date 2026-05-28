{ config, pkgs, agenixPkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./modules/base.nix
    ./modules/arion.nix
    ./modules/services/vaultwarden.nix
    ./modules/services/operations.nix
  ];

  # agenix CLI
  environment.systemPackages = [ agenixPkgs.default ];

  # agenix configuration
  age.ageBin = "${pkgs.age}/bin/age";
  age.identityPaths = [
    "/etc/ssh/ssh_host_ed25519_key"
    "/etc/ssh/ssh_host_rsa_key"
  ];
  age.secretsDir = "/run/agenix";

  system.stateVersion = "25.11";

  networking.hostName = "nix-host";

  portainerSettings.theme = "light";
}
