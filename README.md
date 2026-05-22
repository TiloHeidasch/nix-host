# NixOS Homelab Configuration

This repository contains a declarative NixOS configuration for a homelab setup using NixOS Flakes, Arion for container orchestration, and agenix for secret management.

## Repository Structure

```
.
├── flake.nix                 # Flake definition
├── configuration.nix         # Main NixOS configuration
├── modules/
│   ├── base.nix              # Base system configuration
│   ├── arion.nix             # Docker and Arion setup
│   └── services/
│       └── vaultwarden.nix   # Vaultwarden stack
├── secrets/
│   ├── secrets.nix           # Public key definitions for agenix
│   ├── vaultwarden.env.age   # Encrypted Vaultwarden environment
│   └── cloudflared-vaultwarden.env.age  # Encrypted Cloudflare tunnel token
└── arion/
    └── vaultwarden/
        ├── arion-compose.nix # Arion service definition
        └── arion-pkgs.nix    # nixpkgs import for Arion
```

## Prerequisites

1. A machine capable of running NixOS (VM or bare metal)
2. At least 4GB RAM
3. An SSH key pair for the user (to authorize access and for agenix decryption)
4. (Optional but recommended) A Cloudflare tunnel token for external access

## Setup Instructions

### 1. Initial VM Setup

Install NixOS 25.11 on your target machine. During installation:
- Ensure you enable SSH server
- Create a user (we'll use `tilo` as in this config)
- Note the VM's IP address

### 2. Prepare the Server SSH Key for agenix

On your local machine, run:
```bash
ssh-keyscan <VM_IP_ADDRESS>
```
Copy the entire output (should look like `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA...`).

Replace the `homeserver` value in `secrets/secrets.nix` with this key:
```nix
homeserver = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA...";
```

### 3. Encrypt the Secrets

For each `.age` file in the `secrets/` directory, run:
```bash
agenix -e secrets/vaultwarden.env.age
agenix -e secrets/cloudflared-vaultwarden.env.age
```

This will open your `$EDITOR`. Fill in the contents:

**vaultwarden.env**:
```
VAULTWARDEN_DOMAIN=your-domain.tld
SIGNUPS_ALLOWED=false
INVITATIONS_ALLOWED=false
ADMIN_TOKEN=your-secret-token-here
```

**cloudflared-vaultwarden.env**:
```
TUNNEL_TOKEN=your-cloudflare-tunnel-token-here
```

Save and close the editor to encrypt the files.

### 4. Apply the Configuration

Clone this repository on the VM (or copy the files), then run:
```bash
sudo nixos-rebuild switch --flake .#nix-host
```

This will:
- Build the system configuration
- Start Docker and Arion
- Deploy the Vaultwarden stack via Arion
- Decrypt and mount the secrets at `/run/agenix/`

### 5. Accessing Services

After successful deployment:
- Vaultwarden should be accessible via your Cloudflare tunnel
- The Arion service runs as a systemd service: `arion-vaultwarden`
- Logs can be viewed with: `journalctl -u arion-vaultwarden -f`

## Updating the Configuration

To update the system after making changes:
```bash
sudo nixos-rebuild switch --flake .#nix-host
```

To roll back to a previous generation:
```bash
sudo nixos-rebuild switch --rollback
```

## Managing Secrets

To edit an existing secret:
```bash
agenix -e secrets/<filename>.age
```

To re-encrypt all secrets if you change the public keys in `secrets.nix`:
```bash
agenix -r
```

## Notes

- The `/data/vaultwarden` directory is currently backed by tmpfs (in-memory). For persistent storage, replace the `fileSystems."/data"` entry in `modules/base.nix` with an NFS mount or a proper disk partition.
- The server's SSH host keys are automatically used by agenix for decryption via `age.identityPaths`.
- This configuration follows GitOps principles: the Git repository is the single source of truth. Never modify the live system directly—always make changes via Git and redeploy.

## Troubleshooting

- If the Arion service fails to start, check the logs: `journalctl -u arion-vaultwarden -f`
- Verify Docker is running: `docker info`
- Check that secrets are decrypted: `ls -la /run/agenix/`
- Ensure the VM has internet access to pull Docker images