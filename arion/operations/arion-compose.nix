{ pkgs, ... }:
{
  project.name = "operations";

  services = {
    portainer = {
      service.image = "portainer/portainer-ce:latest";
      service.restart = "unless-stopped";
      service.volumes = [
        "/var/run/docker.sock:/var/run/docker.sock"
        "portainer_data:/data"
      ];
      service.ports = [ "127.0.0.1:9000:9000" ];
    };

    dozzle = {
      service.image = "amir20/dozzle:latest";
      service.restart = "unless-stopped";
      service.volumes = [ "/var/run/docker.sock:/var/run/docker.sock" ];
      service.ports = [ "127.0.0.1:8080:8080" ];
    };
  };

  volumes.portainer_data = {};
}