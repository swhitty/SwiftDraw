docker run -it \
  --publish 8080:80 \
  --rm \
  --mount src="$(pwd)",target=/source,type=bind \
  swift \
  /bin/sh -c "cd source; swift test"