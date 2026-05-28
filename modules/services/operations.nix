{ config, pkgs, lib, ... }:

let
  portainerAdminPasswordFile = config.age.secrets.portainer-admin-password.path;
  portainerTheme = config.portainerSettings.theme;

  runScript = pkgs.writeShellScript "arion-operations-run" ''
    set -euo pipefail

    # Remove existing containers to ensure fresh state
    ${pkgs.docker}/bin/docker rm -f operations-portainer-1 operations-dozzle-1 2>/dev/null || true
    ${pkgs.docker}/bin/docker volume rm operations_portainer_data 2>/dev/null || true

    # Start containers via arion
    ${pkgs.arion}/bin/arion --prebuilt-file ${arionProject} up -d

    # Wait for Portainer to be ready
    ADMIN_PASSWORD=$(cat ${portainerAdminPasswordFile})
    BASE_URL="http://127.0.0.1:9000"
    MAX_RETRIES=30

    for i in $(seq 1 $MAX_RETRIES); do
      if curl -sf "$BASE_URL/api/status" > /dev/null 2>&1; then
        break
      fi
      sleep 2
    done

    # Login and get JWT
    JWT=$(curl -sf -X POST "$BASE_URL/api/auth" \
      -H "Content-Type: application/json" \
      -d "{\"username\":\"admin\",\"password\":\"$ADMIN_PASSWORD\"}" \
      | ${pkgs.jq}/bin/jq -r '.jwt')

    # Create local Docker endpoint if not exists
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

    # Set theme for admin user via user-level API
    ADMIN_ID=$(curl -sf "$BASE_URL/api/users" \
      -H "Authorization: Bearer $JWT" \
      | ${pkgs.jq}/bin/jq '.[] | select(.Username == "admin") | .Id')

    ${pkgs.jq}/bin/jq -n \
      --arg theme "${portainerTheme}" \
      '{ "UserTheme": $theme }' \
      | curl -sf -X PUT "$BASE_URL/api/users/$ADMIN_ID" \
        -H "Authorization: Bearer $JWT" \
        -H "Content-Type: application/json" \
        -d @- > /dev/null

    # Apply global settings
    ${pkgs.jq}/bin/jq -n '{
      "LogoURL": "",
      "DisplayDonationHeader": false,
      "DisplayExternalContributors": false
    }' | curl -sf -X PUT "$BASE_URL/api/settings" \
      -H "Authorization: Bearer $JWT" \
      -H "Content-Type: application/json" \
      -d @- > /dev/null
  '';

  stopScript = pkgs.writeShellScript "arion-operations-stop" ''
    ${pkgs.arion}/bin/arion --prebuilt-file ${arionProject} down
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
      path = with pkgs; [ curl jq docker arion ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = runScript;
        ExecStop = stopScript;
        WorkingDirectory = "/tmp";
      };
    };

    age.secrets.portainer-admin-password = {
      file = ../../secrets/portainer-admin-password.age;
      owner = "root";
      group = "root";
    };
  };
}