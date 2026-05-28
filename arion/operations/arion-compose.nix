{ pkgs, portainerAdminPasswordFile, ... }:
{
  project.name = "operations";

  services = {
    portainer = {
      service.image = "portainer/portainer-ce:latest";
      service.restart = "unless-stopped";
      service.volumes = [
        "/var/run/docker.sock:/var/run/docker.sock"
        "/var/lib/portainer:/data"
        "${portainerAdminPasswordFile}:/run/secrets/portainer-admin-password:ro"
      ];
      service.ports = [ "9000:9000" ];
      service.command = [ "--admin-password-file", "/run/secrets/portainer-admin-password" ];
    };

    dozzle = {
      service.image = "amir20/dozzle:latest";
      service.restart = "unless-stopped";
      service.volumes = [ "/var/run/docker.sock:/var/run/docker.sock" ];
      service.ports = [ "8080:8080" ];
    };
  };
}