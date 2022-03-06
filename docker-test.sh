docker run -it \
  --rm \
  --mount src="$(pwd)",target=/SwiftDraw,type=bind \
  swift \
  /usr/bin/swift test --package-path /SwiftDraw