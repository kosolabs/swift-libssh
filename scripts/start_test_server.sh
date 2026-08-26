#!/bin/zsh

set -e

PORT="${SWIFT_LIBSSH_TEST_PORT:-2222}"
SERVER_DIR="${0:a:h}/test_server"
REPO_DIR="${0:a:h:h}"
HOST_KEY="$SERVER_DIR/host_key_ed25519"
USER_NAME=$(id -un)

# Generated rather than committed: it is only ever trusted by these tests.
if [[ ! -f "$HOST_KEY" ]]; then
    ssh-keygen -q -t ed25519 -N '' -C 'swift-libssh test server' -f "$HOST_KEY"
fi

# sshd appends to its log, so start each run clean.
rm -f "$SERVER_DIR/sshd.log"

/usr/sbin/sshd \
    -f "$SERVER_DIR/sshd_config" \
    -E "$SERVER_DIR/sshd.log" \
    -h "$HOST_KEY" \
    -p "$PORT" \
    -o "PidFile $SERVER_DIR/sshd.pid" \
    -o "AuthorizedKeysFile $REPO_DIR/Tests/Data/id_ed25519.pub" \
    -o "Subsystem sftp internal-sftp -u 0002"

retries=50
while [[ ! -f "$SERVER_DIR/sshd.pid" ]]; do
    if (( retries-- == 0 )); then
        echo "❌ Failed to start SSH server: PID file not found after waiting."
        cat "$SERVER_DIR/sshd.log"
        exit 1
    fi
    sleep 0.1
done

PID=$(cat "$SERVER_DIR/sshd.pid")

echo "✅ SSH Server started on port $PORT as $USER_NAME with PID $PID"
