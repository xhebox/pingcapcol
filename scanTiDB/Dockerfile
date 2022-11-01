FROM alpine:latest

ENV GH_TOKEN=""
ADD ./apk-fastest-mirror.sh ./scanTiDB.sh /
RUN sh /apk-fastest-mirror.sh -t 50 && apk add --no-cache bash github-cli jq coreutils
ENTRYPOINT ["/bin/sh", "-c", "GH_TOKEN=$GH_TOKEN /scanTiDB.sh \"updated:>=$(date -u --date=\"1 day ago\" \"+%Y-%m-%dT%H:%M:%SZ\")\""]
