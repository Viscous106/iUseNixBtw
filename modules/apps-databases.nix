{ config, pkgs, lib, ... }:

# Databases, containers, and VM tooling — ported from the Arch install's
# explicitly-installed package list:
#   postgresql postgis pgvector mongodb-bin mongosh-bin mariadb valkey
#   docker docker-buildx docker-compose docker-compose-cli docker-machine
#   podman lazydocker swtpm distrobox
#
# These are mostly background services, so they're wired through the proper
# NixOS service modules (services.postgresql / services.mongodb /
# services.mysql / services.redis / virtualisation.docker / virtualisation.podman)
# rather than just dumped into environment.systemPackages. Every option/package
# name below was checked against the vendored nixpkgs source before being used
# — see the per-section notes for what was verified and what was skipped.
#
# Portable-drive note: enabling these services is safe across different
# physical machines — sockets/data dirs under /var/lib only get created and
# used the first time the service actually starts on a given host.

{
  # ── PostgreSQL (+ PostGIS, pgvector) ──────────────────────────────────────
  # services.postgresql.extraPlugins was renamed to `extensions` in this
  # nixpkgs (nixos/modules/services/databases/postgresql.nix uses a
  # mkRenamedOptionModule from extraPlugins -> extensions); `extensions` takes
  # a function `ps: [...]` over the postgresql package's own extension set.
  # Both postgis and pgvector exist as ext/postgis.nix and ext/pgvector.nix
  # under pkgs/servers/sql/postgresql/ext, auto-registered under those names.
  services.postgresql = {
    enable = true;
    extensions = ps: with ps; [ postgis pgvector ];
  };

  # ── MongoDB (+ mongosh) ────────────────────────────────────────────────────
  # services.mongodb.enable exists (nixos/modules/services/databases/mongodb.nix).
  # MongoDB's license (SSPL) is marked `free = false` in lib/licenses.nix, so it
  # needs nixpkgs.config.allowUnfree = true — already set in configuration.nix.
  # It has NOT been removed from nixpkgs; two package choices exist:
  #   - pkgs.mongodb (= mongodb-7_0, hiPrio): compiled from source. Unfree
  #     packages aren't built by Hydra's cache, so this means a full local
  #     SCons build (can be very long) on every machine this drive boots on.
  #   - pkgs.mongodb-ce (8.2.6): just fetches the official prebuilt Linux
  #     tarball and patches it for Nix — fast, no compiler needed, and a much
  #     closer functional analog to the AUR `mongodb-bin` package the Arch
  #     side was using.
  # Judgment call: use mongodb-ce for that reason. The mongodb module does
  # NOT auto-add its packages to environment.systemPackages (unlike the mysql/
  # redis/postgresql modules), so mongosh is added explicitly below to get an
  # AUR-mongosh-bin-equivalent CLI on PATH.
  services.mongodb = {
    enable = true;
    package = pkgs.mongodb-ce;
  };

  # ── MariaDB (via the services.mysql module) ───────────────────────────────
  # NixOS has no separate services.mariadb module — services.mysql accepts a
  # MariaDB derivation via `package` (nixos/modules/services/databases/mysql.nix
  # detects `isMariaDB = lib.getName cfg.package == lib.getName pkgs.mariadb`).
  # pkgs.mariadb exists (aliased to mariadb_114 in pkgs/top-level/all-packages.nix).
  # This is intentionally separate from the mysql84 home.package already
  # declared in home/viscous.nix — different engine, both kept.
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
  };

  # ── Valkey (via the services.redis module) ────────────────────────────────
  # There is no services.valkey NixOS module in this nixpkgs. services.redis
  # (nixos/modules/services/databases/redis.nix) is explicitly designed to
  # accept a Valkey package as a drop-in: its systemd ExecStart uses
  # `cfg.package.serverBin or "redis-server"`, and pkgs.valkey's passthru sets
  # `serverBin = "valkey-server"` — so overriding services.redis.package with
  # pkgs.valkey gives a real valkey-server, not redis, under the redis option
  # namespace. `package` is a single top-level option shared by all server
  # instances; `servers.""` is the conventional "default instance" name
  # (port 6379, unix socket /run/redis/redis.sock).
  services.redis.package = pkgs.valkey;
  services.redis.servers."" = {
    enable = true;
  };

  # ── Docker ─────────────────────────────────────────────────────────────────
  # virtualisation.docker.enable brings in the daemon + pkgs.docker (default
  # `package`). pkgs.docker itself is built with `buildxSupport = true` and
  # `composeSupport = true` by default (pkgs/applications/virtualization/docker/
  # default.nix), which wraps it to find docker-buildx/docker-compose as CLI
  # plugins via DOCKER_CLI_PLUGIN_DIRS — so `docker buildx ...` and
  # `docker compose ...` already work with no extra wiring.
  #
  # docker-compose and docker-buildx are still added to systemPackages below
  # so the standalone `docker-compose` / `docker-buildx` commands (the AUR
  # docker-compose / docker-compose-cli / docker-buildx packages' actual
  # behavior — invoked without the leading "docker" word) are also on PATH.
  # nixpkgs has exactly one docker-compose package (Go-based v2 standalone
  # binary, pkgs/applications/virtualization/docker/compose.nix) — there is no
  # separate package matching AUR's "docker-compose-cli"; the one
  # pkgs.docker-compose covers both Arch package names.
  #
  # docker-machine: checked pkgs/applications/networking/cluster/docker-machine
  # — only docker-machine-hyperkit (a driver plugin) is defined in
  # all-packages.nix; the base docker-machine package/attribute does not exist
  # in this nixpkgs (no default.nix in that directory, and no alias). Skipped
  # as unavailable — docker-machine has been unmaintained upstream for years,
  # which likely explains the removal.
  virtualisation.docker.enable = true;

  # ── Podman ─────────────────────────────────────────────────────────────────
  # virtualisation.podman.enable exists (nixos/modules/virtualisation/podman).
  # dockerCompat (aliases a `docker` binary to podman) is left at its default
  # (false) since real Docker is also enabled above — enabling both would
  # fight over the `docker` command name.
  virtualisation.podman.enable = true;

  # ── libvirt/QEMU ───────────────────────────────────────────────────────────
  # Arch had libvirtd + virtlogd enabled (VM passthrough scripts under
  # ~/.config/hypr/scripts/vm-passthrough.sh reference it) but this was never
  # ported. virtualisation.libvirtd.enable brings up both libvirtd and
  # virtlogd; qemu is the default backend. viscous needs to be in the
  # `libvirtd` group to manage VMs without sudo (added in configuration.nix).
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  # ── Plain CLI/VM-tooling packages ─────────────────────────────────────────
  # All verified present in pkgs/by-name/ under these exact attribute names:
  #   lazydocker  (pkgs/by-name/la/lazydocker)
  #   swtpm       (pkgs/by-name/sw/swtpm)
  #   distrobox   (pkgs/by-name/di/distrobox)
  #   docker-compose, docker-buildx (see Docker section above)
  #   mongosh     (pkgs/by-name/mo/mongosh — see MongoDB section above)
  environment.systemPackages = with pkgs; [
    lazydocker
    swtpm
    distrobox
    docker-compose
    docker-buildx
    mongosh
  ];
}
