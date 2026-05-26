{ pkgs, ... }:

let
  arionProject = pkgs.arion.build {
    modules = [ ./../../arion/operations/arion-compose.nix ];
    pkgs = import ./../../arion/operations/arion-pkgs.nix { inherit pkgs; };
  };
in
{
  networking.firewall.allowedTCPPorts = [ 9000 8080 ];
  systemd.services.arion-operations = {
    description = "Operations stack (Portainer, Dozzle) managed by Arion";
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
}