#!/bin/bash
docker buildx build --platform=linux/arm64,linux/amd64 -t xhebox/scantidb:latest --push .
