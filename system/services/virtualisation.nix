{ pkgs, ... }:

{
  virtualisation.docker.enable = true;
  # Socket-activated: dockerd starts on first use instead of adding ~7 s to
  # boot. Containers with a restart policy only come back once dockerd runs.
  virtualisation.docker.enableOnBoot = false;

  virtualisation.podman.enable = true;  # no dockerCompat: real docker owns `docker`

  environment.systemPackages = with pkgs; [
    docker-compose  # standalone `docker-compose` (docker compose works too)
    docker-buildx
  ];
}
