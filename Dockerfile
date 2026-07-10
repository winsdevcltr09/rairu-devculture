FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive \
    NTFY_TOPIC=yans-proton \
    BORE_SERVER=bore.pub \
    ROOT_PASS=craxid \
    TZ=Asia/Jakarta

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates openssh-server curl python3 \
        vim nano sudo net-tools wget htop git unzip \
        iproute2 iputils-ping procps passwd tmux screen \
        lsof dnsutils jq tzdata supervisor && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    update-ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install bore v0.6.0 (SSH langsung tanpa install di client)
RUN curl -fsSL "https://github.com/ekzhang/bore/releases/download/v0.6.0/bore-v0.6.0-x86_64-unknown-linux-musl.tar.gz" \
        -o /tmp/bore.tar.gz && \
    tar -xzf /tmp/bore.tar.gz -C /usr/local/bin/ && \
    chmod +x /usr/local/bin/bore && \
    rm /tmp/bore.tar.gz && \
    bore --version

# Configure SSH
RUN mkdir -p /run/sshd && \
    echo "root:craxid" | chpasswd && \
    ssh-keygen -A && \
    sed -i \
      -e 's/#PermitRootLogin.*/PermitRootLogin yes/' \
      -e 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' \
      -e 's/#PasswordAuthentication yes/PasswordAuthentication yes/' \
      -e 's/PasswordAuthentication no/PasswordAuthentication yes/' \
      -e 's/#ClientAliveInterval.*/ClientAliveInterval 60/' \
      -e 's/#ClientAliveCountMax.*/ClientAliveCountMax 10/' \
      -e 's/#MaxSessions.*/MaxSessions 20/' \
      -e 's/#TCPKeepAlive.*/TCPKeepAlive yes/' \
      /etc/ssh/sshd_config

# supervisord config untuk hermes-gateway dan service lainnya
COPY supervisord.conf /etc/supervisord.conf
RUN mkdir -p /etc/supervisor/conf.d
COPY hermes.conf /etc/supervisor/conf.d/hermes.conf

# SSH login notification
COPY notify-ssh-login.sh /etc/profile.d/notify-ssh-login.sh
RUN chmod +x /etc/profile.d/notify-ssh-login.sh

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=5 \
    CMD pgrep sshd > /dev/null || exit 1

CMD ["/entrypoint.sh"]
