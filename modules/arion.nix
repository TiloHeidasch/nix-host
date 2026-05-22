{ config, pkgs, ... }:

{
  # Enable Docker
  virtualisation.docker.enable = true;

  # Install Arion and docker-compose
  environment.systemPackages = with pkgs; [
    arion
    docker-compose
  ];

  # Ensure the tilo user is in the docker group (already set in base.nix, but we can set again)
  # This is idempotent.
  users.users.tilo.extraGroups = [ "wheel" "docker" ];
}