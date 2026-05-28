{ config, pkgs, lib, ... }:

let
  portainerAdminPasswordFile = config.age.secrets.portainer-admin-password.path;
  portainerTheme = config.portainerSettings.theme;

  arionProject = pkgs.arion.build {
    modules = [
      ({ ... }: {
        _module.args = { inherit portainerAdminPasswordFile; };
      })
      ./../../arion/operations/arion-compose.nix
    ];
    pkgs = import ./../../arion/operations/arion-pkgs.nix { inherit pkgs; };
  };

  runScript = pkgs.writeShellScript "arion-operations-run" ''
    set -euo pipefail

    # Remove old containers and ensure clean state
    ${pkgs.docker}/bin/docker rm -f operations-portainer-1 operations-dozzle-1 2>/dev/null || true
    rm -rf /var/lib/portainer
    mkdir -p /var/lib/portainer

    # Start containers via arion
    ${pkgs.arion}/bin/arion --prebuilt-file ${arionProject} up -d

    # --- API configuration (individual calls can fail gracefully) ---
    ADMIN_PASSWORD=$(cat ${portainerAdminPasswordFile})
    BASE_URL="http://127.0.0.1:9000"

    # Wait for portainer to respond on health endpoint
    echo "Waiting for Portainer to be ready..."
    for i in $(seq 1 30); do
      HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/status" 2>/dev/null || echo "000")
      if [ "$HTTP_CODE" = "200" ]; then
        echo "Portainer ready after $((i * 2)) seconds"
        break
      fi
      sleep 2
    done

    # Portainer needs extra time after --admin-password-file on first start
    sleep 3

    # Authenticate
    echo "Authenticating with Portainer API..."
    JWT=$(curl -s -X POST "$BASE_URL/api/auth" \
      -H "Content-Type: application/json" \
      -d "{\"username\":\"admin\",\"password\":\"$ADMIN_PASSWORD\"}" \
      | ${pkgs.jq}/bin/jq -r '.jwt' 2>/dev/null || echo "")

    if [ -z "$JWT" ]; then
      echo "WARNING: Portainer auth failed - admin password file not processed yet, retrying..."
      sleep 10
      JWT=$(curl -s -X POST "$BASE_URL/api/auth" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"admin\",\"password\":\"$ADMIN_PASSWORD\"}" \
        | ${pkgs.jq}/bin/jq -r '.jwt' 2>/dev/null || echo "")
    fi

    if [ -z "$JWT" ]; then
      echo "WARNING: Portainer auth still failing - admin may need manual setup"
      echo "Password file: ${portainerAdminPasswordFile}"
      echo "Trying with password contents: $(cat ${portainerAdminPasswordFile} | head -c 20)..."
      exit 0
    fi

    echo "Auth successful, configuring Portainer..."

    # Create local docker endpoint (idempotent)
    curl -s -o /dev/null -w "Create endpoint HTTP %{http_code}\n" \
      -X POST "$BASE_URL/api/endpoints" \
      -H "Authorization: Bearer $JWT" \
      -H "Content-Type: application/json" \
      -d '{"Name":"local","EndpointType":1,"URL":"unix:///var/run/docker.sock","PublicURL":""}' || true

    # Get admin user ID
    ADMIN_ID=$(curl -s "$BASE_URL/api/users" \
      -H "Authorization: Bearer $JWT" \
      | ${pkgs.jq}/bin/jq '.[] | select(.Username == "admin") | .Id' 2>/dev/null || echo "")

    if [ -n "$ADMIN_ID" ]; then
      echo "Setting theme to ${portainerTheme} for admin user $ADMIN_ID..."
      ${pkgs.jq}/bin/jq -n --arg theme "${portainerTheme}" '{ "UserTheme": $theme }' \
        | curl -s -o /dev/null -w "Set theme HTTP %{http_code}\n" \
          -X PUT "$BASE_URL/api/users/$ADMIN_ID" \
          -H "Authorization: Bearer $JWT" \
          -H "Content-Type: application/json" -d @- || true
    else
      echo "WARNING: Could not find admin user ID"
    fi

    # Apply global settings
    curl -s -o /dev/null -w "Global settings HTTP %{http_code}\n" \
      -X PUT "$BASE_URL/api/settings" \
      -H "Authorization: Bearer $JWT" \
      -H "Content-Type: application/json" \
      -d '{"LogoURL":"","DisplayDonationHeader":false,"DisplayExternalContributors":false}' || true

    echo "Portainer initialization complete"
  '';

  stopScript = pkgs.writeShellScript "arion-operations-stop" ''
    ${pkgs.arion}/bin/arion --prebuilt-file ${arionProject} down
  '';
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