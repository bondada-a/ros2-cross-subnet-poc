FROM alpine:3.19

# iptables-legacy: explicit choice over nft backend for predictable conntrack
#   behavior across stage switches.
# iproute2: `ip` command for inspecting/adjusting routes during debugging.
# conntrack-tools: `conntrack -F` lets us flush stateful table between stages
#   so the negative test is a clean re-test rather than riding existing flows.
# tcpdump: on-board packet capture when a stage misbehaves.
# bash: our scripts use bash-specific features; ash would work but readability wins.
RUN apk add --no-cache \
        iptables \
        iproute2 \
        conntrack-tools \
        tcpdump \
        bash

# All stage scripts and helpers live at /router/ inside the container.
WORKDIR /router

COPY firewall-stage1-deny.sh    /router/
COPY firewall-stage2-allow.sh   /router/
COPY firewall-stage3-tcponly.sh /router/
COPY show-rules.sh              /router/
COPY entrypoint.sh              /router/

RUN chmod +x /router/*.sh

# ip_forward is set at runtime (requires NET_ADMIN + host sysctl access).
# Scripts need to be re-runnable, so the entrypoint applies Stage 1 at boot
# and then blocks forever -- stage switches come via `docker exec`.
ENTRYPOINT ["/router/entrypoint.sh"]
