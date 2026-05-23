{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./modules/base.nix
    ./modules/arion.nix
    ./modules/services/vaultwarden.nix
  ];

  # agenix CLI
  environment.systemPackages = [
    (pkgs.callPackage "${pkgs.agenix}/pkgs/agenix.nix" {})
  ];

  # agenix configuration
  age.ageBin = "${pkgs.age}/bin/age";
  age.identityPaths = [
    "/etc/ssh/ssh_host_ed25519_key"
    "/etc/ssh/ssh_host_rsa_key"
  ];
  age.secretsDir = "/run/agenix";

  # Ensure the secrets directory exists
  systemd.tmpfiles.rules = [
    "d /run/agenix 0755 root root"
  ];

  system.stateVersion = "25.11";

  # Hostname
  networking.hostName = "nix-host";

  # Use the unstable channel for nixos-25.11 (already set in flake)
}