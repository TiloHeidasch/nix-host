{ config, pkgs, lib, ... }:

let
  portainerAdminPasswordFile = config.age.secrets.portainer-admin-password.path;
  portainerTheme = config.portainerSettings.theme;

  portainerInit = pkgs.writeShellScript "portainer-init" ''
    set -euo pipefail

    ADMIN_PASSWORD=$(cat ${portainerAdminPasswordFile})
    BASE_URL="http://127.0.0.1:9000"
    MAX_RETRIES=30

    for i in $(seq 1 $MAX_RETRIES); do
      if curl -sf "$BASE_URL/api/status" > /dev/null 2>&1; then
        break
      fi
      sleep 2
    done

    JWT=$(curl -sf -X POST "$BASE_URL/api/auth" \
      -H "Content-Type: application/json" \
      -d "{\"username\":\"admin\",\"password\":\"$ADMIN_PASSWORD\"}" \
      | ${pkgs.jq}/bin/jq -r '.jwt')

    ENDPOINT_COUNT=$(curl -sf "$BASE_URL/api/endpoints" \
      -H "Authorization: Bearer $JWT" \
      | ${pkgs.jq}/bin/jq 'length')

    if [ "$ENDPOINT_COUNT" -eq 0 ]; then
      curl -sf -X POST "$BASE_URL/api/endpoints" \
        -H "Authorization: Bearer $JWT" \
        -H "Content-Type: application/json" \
        -d '{
          "Name": "local",
          "EndpointType": 1,
          "URL": "unix:///var/run/docker.sock",
          "PublicURL": ""
        }' > /dev/null
    fi

    SETTINGS=$(${pkgs.jq}/bin/jq -n \
      --arg theme "${portainerTheme}" \
      '{
        "LogoURL": "",
        "DisplayDonationHeader": false,
        "DisplayExternalContributors": false,
        "Theme": $theme
      }')

    curl -sf -X PUT "$BASE_URL/api/settings" \
      -H "Authorization: Bearer $JWT" \
      -H "Content-Type: application/json" \
      -d "$SETTINGS" > /dev/null
  '';

  arionProject = pkgs.arion.build {
    modules = [
      ({ ... }: {
        _module.args = { inherit portainerAdminPasswordFile; };
      })
      ./../../arion/operations/arion-compose.nix
    ];
    pkgs = import ./../../arion/operations/arion-pkgs.nix { inherit pkgs; };
  };
in
{
  options.portainerSettings = {
    theme = lib.mkOption {
      type = lib.types.enum [ "auto" "light" "dark" "highcontrast" ];
      default = "auto";
      description = "Portainer UI theme";
    };
  };

  config = {
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

    systemd.services.portainer-init = {
      description = "Initialize Portainer (create endpoint, apply settings)";
      after = [ "arion-operations.service" ];
      wants = [ "arion-operations.service" ];
      wantedBy = [ "multi-user.target" ];
      enable = true;
      path = with pkgs; [ curl jq ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = portainerInit;
      };
    };

    age.secrets.portainer-admin-password = {
      file = ../../secrets/portainer-admin-password.age;
      owner = "root";
      group = "root";
    };
  };
}