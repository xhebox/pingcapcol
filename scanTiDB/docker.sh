#!/bin/bash
set -ex
docker build -t xhebox/scantidb:latest .
docker push xhebox/scantidb:latest
