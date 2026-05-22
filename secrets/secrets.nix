let
  tilo = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFR/nYIXmQFyYysElpHtcL8xwKqADI7++5+77e3b1iJw";
  nixos = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINoPvamLrlg1J4N0KZIKP8tkDYzg4ldi5u37TzYPS4MK";
  users = [ tilo ];
  systems = [ nixos ];
in
{
  "vaultwarden.env.age".publicKeys = users ++ systems;
  "cloudflared-vaultwarden.env.age".publicKeys = users ++ systems;
}