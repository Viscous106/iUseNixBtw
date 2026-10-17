# Who this install belongs to. Every module gets these as `user`.
#
# setup.sh rewrites both fields in the copy it installs (it prompts for a
# username and password). Must stay git-tracked: flakes can't see untracked files.
#
# hashedPassword is only applied when the account is first created; on a
# running system use `passwd`. New hash: `mkpasswd -m sha-512`.
{
  username = "viscous";

  # Generated with `mkpasswd -m sha-512`.
  hashedPassword = "$6$KAEKKvbZIFl93S.a$bH1h1M.sCzqmvX3SZkK6QcHfjP31vBadi4V/dpWPlL2zIeQ5ZQ85NwrE9sylDZ3Wb/YOeS8lSHtHeJhGbveic0";
}
