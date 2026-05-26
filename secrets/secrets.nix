let
  tilo = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFR/nYIXmQFyYysElpHtcL8xwKqADI7++5+77e3b1iJw";
  nixos-host = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEtrYNR4QhXIRXcST67pnRyaQ133yM0+U+xgu3ZiCWts";
  users = [ tilo ];
  systems = [ nixos-host ];
in
{
  "vaultwarden.env.age".publicKeys = users ++ systems;
  "cloudflared-vaultwarden.env.age".publicKeys = users ++ systems;
  "portainer-admin-password.age".publicKeys = users ++ systems;
}