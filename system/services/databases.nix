{ pkgs, ... }:

{
  # All four listen on loopback only.
  services.postgresql = {
    enable = true;
    extensions = ps: with ps; [ postgis pgvector ];
  };

  # mongodb-ce is the prebuilt upstream tarball; pkgs.mongodb is unfree and
  # would compile from source locally on every bump.
  services.mongodb = {
    enable  = true;
    package = pkgs.mongodb-ce;
  };

  # MariaDB through the mysql module. Its default bind is 0.0.0.0, so it is
  # pinned to loopback like the others.
  services.mysql = {
    enable  = true;
    package = pkgs.mariadb;
    settings.mysqld.bind-address = "127.0.0.1";
  };

  # Valkey through the redis module (it runs valkey-server via passthru.serverBin).
  services.redis.package = pkgs.valkey;
  services.redis.servers."" = {
    enable = true;
  };

  environment.systemPackages = [ pkgs.mongosh ];  # the mongodb module doesn't add it
}
