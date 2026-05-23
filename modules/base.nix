{ config, pkgs, ... }:

{
  # Bootloader (systemd-boot for EFI)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.useDHCP = true;
  networking.useNetworkd = true;

  # SSH
  services.openssh.enable = true;
  services.openssh.permitRootLogin = "no";
  services.openssh.passwordAuthentication = false;
  users.users.tilo.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB87Pygbk2zeC/PXLyXSvdImJIpLZJOtqEveO+n+23Zr"
  ];

  # Nix settings
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.gc.automatic = true;
  nix.gc.dates = "weekly";
  nix.gc.options = "--max-live 5";

  # Timezone and Locale
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "de_DE.UTF-8";

  # Create user tilo
  users.users.tilo = {
    isNormalUser = true;
    description = "Tilo Heidasch";
    extraGroups = [ "wheel" "docker" ];  # wheel for sudo, docker for arion
    uid = 1000;
    home = "/home/tilo";
    createHome = true;
  };

  # Enable sudo for wheel group
  security.sudo.wheelNeedsPassword = false;

  # Basic packages
  environment.systemPackages = with pkgs; [
    curl
    git
    vim
    htop
    # Add any other base utilities
  ];

  # Ensure /data directory exists for vaultwarden data
  fileSystems."/data" = {
    device = "tmpfs";  # Placeholder - will be replaced by NFS mount later
    fsType = "tmpfs";
    options = [ "size=2g" ];
  };
}