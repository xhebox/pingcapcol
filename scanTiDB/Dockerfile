FROM alpine:latest

ENV GH_TOKEN=""
ADD ./scanTiDB.sh https://raw.githubusercontent.com/njhallett/apk-fastest-mirror/main/apk-fastest-mirror.sh /
RUN sh /apk-fastest-mirror.sh -t 50 && apk add --no-cache bash github-cli jq coreutils
ENTRYPOINT ["/bin/sh", "-c", "GH_TOKEN=$GH_TOKEN /scanTiDB.sh \"updated:>=$(date -u --date=\"70 minutes ago\" \"+%Y-%m-%dT%H:%M:%SZ\")\""]
