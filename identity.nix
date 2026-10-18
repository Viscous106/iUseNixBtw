# Who this install belongs to (`user` in every module); setup.sh rewrites it, and it must stay git-tracked.
# hashedPassword only applies at account creation; afterwards use `passwd` (new hash: mkpasswd -m sha-512).
{
  username = "viscous";

  # Generated with `mkpasswd -m sha-512`.
  hashedPassword = "$6$KAEKKvbZIFl93S.a$bH1h1M.sCzqmvX3SZkK6QcHfjP31vBadi4V/dpWPlL2zIeQ5ZQ85NwrE9sylDZ3Wb/YOeS8lSHtHeJhGbveic0";
}
