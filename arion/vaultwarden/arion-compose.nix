{ pkgs, cloudflaredEnvFile, ... }:
{
  project.name = "vaultwarden";

  services = {
    cloudflared = {
      service.image = "cloudflare/cloudflared:latest";
      service.restart = "unless-stopped";
      service.command = [ "tunnel" "run" ];
      service.env_file = [ cloudflaredEnvFile ];
    };
  };
}