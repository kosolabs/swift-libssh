default: test

build-test-server:
    docker compose -f Tests/docker-compose.yml build

start-test-server: build-test-server
    docker compose -f Tests/docker-compose.yml up -d --wait

stop-test-server:
    docker compose -f Tests/docker-compose.yml down

test: stop-test-server start-test-server
    swift test --no-parallel

# Hammer the library with concurrent transfers against the docker test server.
# Pass extra flags through, e.g. `just stress --topology per-worker-session`.
stress *args="--workers 8 --iterations 25": start-test-server
    swift run -c release SwiftSSH stress \
        -i Tests/Data/id_ed25519 -p 2222 -l myuser localhost {{args}}
