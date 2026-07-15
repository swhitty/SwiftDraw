container run -it \
  --rm \
  --mount src="$(pwd)",target=/SwiftDraw,type=bind \
  swift:6.3 \
  /usr/bin/swift test --package-path /SwiftDraw