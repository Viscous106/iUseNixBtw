#!/usr/bin/env bash
echo "Signing called with args: $@" >> /tmp/git-sign-debug.log
unset SSH_AUTH_SOCK
ssh-keygen "$@"
