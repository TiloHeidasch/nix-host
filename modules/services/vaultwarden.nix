{ config, pkgs, ... }:

let
  cloudflaredEnvFile = config.age.secrets.cloudflared-vaultwarden.path;

  arionProject = pkgs.arion.build {
    modules = [
      ({ ... }: {
        _module.args = { inherit cloudflaredEnvFile; };
      })
      ./../../arion/vaultwarden/arion-compose.nix
    ];
    pkgs = import ./../../arion/vaultwarden/arion-pkgs.nix { inherit pkgs; };
  };
in
{
  systemd.services.arion-vaultwarden = {
    description = "Cloudflared service managed by Arion";
    after = [ "virtualisation.docker.service" ];
    wants = [ "virtualisation.docker.service" ];
    wantedBy = [ "multi-user.target" ];
    enable = true;
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.arion}/bin/arion --prebuilt-file ${arionProject} up -d";
      ExecStop = "${pkgs.arion}/bin/arion --prebuilt-file ${arionProject} down";
      WorkingDirectory = "/tmp";
    };
  };

  age.secrets.cloudflared-vaultwarden = {
    file = ../../secrets/cloudflared-vaultwarden.env.age;
    owner = "root";
    group = "root";
  };
}