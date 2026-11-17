#!/bin/sh
# Runs the tests on Linux with Apple's `container` tool, as CI's linux_swift_* jobs do.
# SWIFT_VERSION picks the swift image (default 6.4, as linux_swift_6_4); CI also runs 6.2 and 6.3:
#   SWIFT_VERSION=6.2 ./container-run-tests.sh
# Extra arguments go to `swift test`, e.g. ./container-run-tests.sh --filter SVGHostileTests
# The checkout is mounted read-only and copied inside the container (without .git and .build):
# Linux products don't mix with the macOS .build directory, and Swift 6.2's Foundation can't
# copy the Test.bundle resources out of the bind mount.
set -e

SWIFT_VERSION="${SWIFT_VERSION:-6.4}"

TTY=""
[ -t 1 ] && TTY="-it"

container run $TTY \
  --rm \
  --mount src="$(pwd)",target=/SwiftDraw,type=bind,readonly \
  "swift:$SWIFT_VERSION" \
  /bin/sh -c '
    set -e
    mkdir /tmp/src
    tar -C /SwiftDraw --exclude=./.git --exclude="*/.build" --exclude=./.build -cf - . | tar -C /tmp/src -xf -
    exec /usr/bin/swift test --package-path /tmp/src --scratch-path /tmp/build "$@"
  ' sh "$@"
