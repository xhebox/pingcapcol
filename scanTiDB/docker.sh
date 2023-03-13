#!/bin/bash
set -ex
docker buildx build --platform linux/amd64,linux/arm64 --push -t xhebox/scantidb:latest .
