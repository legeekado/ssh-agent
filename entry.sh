#!/bin/bash
# Copyright (c) Andreas Urbanski, 2018
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# Print a debug message if debug mode is on ($DEBUG is not empty)
# @param message
debug_msg ()
{
  if [ -n "$DEBUG" ]; then
    echo "$@"
  fi
}

case "$1" in
  # Start ssh-agent
  ssh-agent)

  # Create proxy-socket for ssh-agent (to give everyone acceess to the ssh-agent socket)
  echo "Creating a proxy socket..."
  rm ${SSH_AUTH_SOCK} ${SSH_AUTH_PROXY_SOCK} > /dev/null 2>&1
  socat UNIX-LISTEN:${SSH_AUTH_PROXY_SOCK},perm=0666,fork UNIX-CONNECT:${SSH_AUTH_SOCK} &

  echo "Launching ssh-agent..."
  exec /usr/bin/ssh-agent -a ${SSH_AUTH_SOCK} -d
  ;;

	# Manage SSH identities
	ssh-add)
  shift # remove argument from array

  # .ssh folder from host is expected to be mounted on /.ssh
  # We copy keys from there into /root/.ssh and fix permissions (necessary on Windows hosts)
  host_ssh_path="/.ssh"
  if [ -d $host_ssh_path ]; then
    debug_msg "Copying host SSH keys and setting proper permissions..."
    cp -a $host_ssh_path/. ~/.ssh/
    chmod 700 ~/.ssh
    chmod 600 ~/.ssh/*
    chmod 644 ~/.ssh/*.pub
  fi

  # Make sure the key exists if provided.
  # When $ssh_key_path is empty, ssh-agent will be looking for both id_rsa and id_dsa in the home directory.
  ssh_key_path=""
  if [ -n "$1" ] && [ -f "/root/.ssh/$1" ]; then
    ssh_key_path="/root/.ssh/$1"
    shift # remove argument from array
  fi

  # Calling ssh-add. This should handle all cases.
  _command="ssh-add $ssh_key_path $@"
  debug_msg "Executing: $_command"

  # When $key_path is empty, ssh-agent will be looking for both id_rsa and id_dsa in the home directory.
  # NOTE: We do a sed hack here to strip out '/root/.ssh' from the key path in the output from ssh-add, since this
  # path may confuse people.
  # echo "Press ENTER or CTRL+C to skip entering passphrase (if any)."
  $_command 2>&1 0>&1 | sed 's/\/root\/.ssh\///g'

  # Return first command exit code
  exit ${PIPESTATUS[0]}
  ;;
	*)
  exec $@
  ;;
esac
