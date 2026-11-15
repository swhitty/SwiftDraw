#!/bin/sh
# Runs the tests on Linux (as CI's linux_swift_6_4 job) with Apple's `container` tool.
# Extra arguments go to `swift test`, e.g. ./container-run-tests.sh --filter SVGHostileTests
# Builds inside the container so Linux products don't mix with the macOS .build directory.
set -e

TTY=""
[ -t 1 ] && TTY="-it"

container run $TTY \
  --rm \
  --mount src="$(pwd)",target=/SwiftDraw,type=bind \
  swift:6.4 \
  /usr/bin/swift test --package-path /SwiftDraw --scratch-path /tmp/build "$@"
