FROM alpine:latest
COPY ./workload-create.sh /opt/
COPY ./apply-change.sh /opt/
