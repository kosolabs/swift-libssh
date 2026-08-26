default: test

start-test-server: stop-test-server
    ./scripts/start_test_server.sh

stop-test-server:
    ./scripts/stop_test_server.sh

test: start-test-server
    swift test

stress *args="--workers 8 --iterations 25": start-test-server
    swift run -c release SwiftSSH stress \
        -i Tests/Data/id_ed25519 -p 2222 -l "$(whoami)" localhost {{args}}
