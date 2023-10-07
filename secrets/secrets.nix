let
  yanda =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN5K1l3qutCgwLC7262LphxXg4LNSVE3EazdiOGxZSlJ";
  # For machines, get the key from /etc/ssh/
  earl_grey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIONeh5JFkxCuDO8v6wFV1AXnZfkXljwLLW9IUe63meNV root@nixos";
in { "cloudflare.age".publicKeys = [ yanda earl_grey ]; }
