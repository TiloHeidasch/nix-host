{ pkgs, cloudflaredEnvFile, vaultwardenEnvFile, ... }:
{
  project.name = "vaultwarden";

  services = {
    cloudflared = {
      service.image = "cloudflare/cloudflared:latest";
      service.restart = "unless-stopped";
      service.command = [ "tunnel" "run" ];
      service.env_file = [ cloudflaredEnvFile ];
    };

    vaultwarden = {
      service.image = "vaultwarden/server:latest";
      service.restart = "unless-stopped";
      service.volumes = [ "/data/vaultwarden:/data" ];
      service.env_file = [ vaultwardenEnvFile ];
      service.healthcheck = {
        service.healthcheck.test = [ "CMD" "curl" "-f" "http://localhost:80/alive" ];
        service.healthcheck.interval = "30s";
        service.healthcheck.timeout = "10s";
        service.healthcheck.retries = 5;
        service.healthcheck.startPeriod = "30s";
      };
    };
  };
}