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
│       ├── vaultwarden.nix   # Vaultwarden + Cloudflared stack
│       └── operations.nix    # Operations stack (Portainer, Dozzle)
├── secrets/
│   ├── secrets.nix           # Public key definitions for agenix
│   ├── vaultwarden.env.age   # Encrypted Vaultwarden environment
│   ├── cloudflared-vaultwarden.env.age  # Encrypted Cloudflare tunnel token
│   └── portainer-admin-password.age     # Encrypted Portainer admin password
├── arion/
│   ├── vaultwarden/
│   │   ├── arion-compose.nix
│   │   └── arion-pkgs.nix
│   └── operations/
│       ├── arion-compose.nix
│       └── arion-pkgs.nix
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

Replace the placeholder in `secrets/secrets.nix` with this key:
```nix
nixos-host = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA...";
```

## Creating Secrets

Each `*.age` file in `secrets/` must be created with agenix before the first build. The
`secrets/secrets.nix` file defines which SSH keys are allowed to encrypt/decrypt.

```bash
# Vaultwarden env file
echo 'VAULTWARDEN_DOMAIN=your-domain.tld
SIGNUPS_ALLOWED=false
INVITATIONS_ALLOWED=false
ADMIN_TOKEN=your-secret-token-here' | agenix -i <identity> -e secrets/vaultwarden.env.age

# Cloudflared tunnel token
echo 'TUNNEL_TOKEN=your-cloudflare-tunnel-token-here' | agenix -i <identity> -e secrets/cloudflared-vaultwarden.env.age

# Portainer admin password (plaintext, used with --admin-password-file flag)
echo -n 'your-password' | agenix -i <identity> -e secrets/portainer-admin-password.age
```

The `<identity>` must be one of the SSH keys listed in `secrets/secrets.nix`:
- Your user key: `~/.ssh/id_ed25519` (on your local machine)
- The host key: `/etc/ssh/ssh_host_ed25519_key` (on the NixOS machine, needs `sudo`)

**Example on the NixOS machine (as root):**
```bash
cd /path/to/nix-host/secrets
echo -n 'admin' | sudo agenix -i /etc/ssh/ssh_host_ed25519_key -e portainer-admin-password.age
```

### Encryption rules

| File | Identity (public key owner) |
|---|---|
| `secrets/vaultwarden.env.age` | user + host |
| `secrets/cloudflared-vaultwarden.env.age` | user + host |
| `secrets/portainer-admin-password.age` | user + host |

## Applying the Configuration

On the NixOS machine, clone the repo and apply:

```bash
git clone https://github.com/TiloHeidasch/nix-host.git && cd nix-host
sudo nixos-rebuild switch --flake .#nix-host
```

To update after making changes:
```bash
cd /path/to/nix-host && git fetch origin && git reset --hard origin/main && sudo nixos-rebuild switch --flake .#nix-host
```

This will:
- Build the system configuration
- Start Docker and Arion
- Deploy all stacks via Arion
- Decrypt and mount the secrets at `/run/agenix/`

## Accessing Services

After successful deployment:

| Service | URL | Credentials |
|---|---|---|
| Portainer | `http://<host>:9000` | `admin` / see `portainer-admin-password.age` |
| Dozzle | `http://<host>:8080` | none (view-only logs) |
| Vaultwarden | via Cloudflare tunnel | configured in `vaultwarden.env.age` |

The Arion services run as systemd services:
```bash
journalctl -u arion-vaultwarden -f
journalctl -u arion-operations -f
```

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

- If an Arion service fails to start, check its logs: `journalctl -u arion-vaultwarden -f` / `journalctl -u arion-operations -f`
- Verify Docker is running: `docker info`
- Check that secrets are decrypted: `ls -la /run/agenix/`
- If Portainer keeps asking for initial setup, delete its data and restart:
  ```bash
  sudo rm -rf /var/lib/portainer && sudo systemctl restart arion-operations
  ```
- Ensure the VM has internet access to pull Docker images