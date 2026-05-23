{ config, pkgs, ... }:

let
  # Resolve secret paths in NixOS context (where agenix is available)
  cloudflaredEnvFile = config.age.secrets.cloudflared-vaultwarden.env.path;
  vaultwardenEnvFile = config.age.secrets.vaultwarden.env.path;

  # Build the Arion project, passing secret paths via _module.args
  arionProject = pkgs.arion.build {
    modules = [
      ({ ... }: {
        _module.args = { inherit cloudflaredEnvFile vaultwardenEnvFile; };
      })
      ./../../arion/vaultwarden/arion-compose.nix
    ];
    pkgs = import ./../../arion/vaultwarden/arion-pkgs.nix { inherit pkgs; };
  };
in
{
  # Ensure the data directory for vaultwarden exists
  fileSystems."/data/vaultwarden" = {
    device = "";  # We'll bind mount from the base /data/vaultwarden
    fsType = "none";
    options = [ "bind" "/data/vaultwarden" ];
  };

  # Systemd service to manage the Arion project
  systemd.services.arion-vaultwarden = {
    description = "Vaultwarden service managed by Arion";
    after = [ "virtualisation.docker.service" ];
    wants = [ "virtualisation.docker.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.arion}/bin/arion --prebuilt-file ${arionProject} up -d";
      ExecStop = "${pkgs.arion}/bin/arion --prebuilt-file ${arionProject} down";
      WorkingDirectory = "/tmp";  # Working directory doesn't matter much for arion with --prebuilt-file
    };
  };

  # Enable the service
  systemd.services.arion-vaultwarden.enable = true;
}