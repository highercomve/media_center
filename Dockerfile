FROM alpine as qemu

RUN if [ -n "arm" ]; then \
		wget -O /qemu-arm-static https://github.com/multiarch/qemu-user-static/releases/download/v4.2.0-2/qemu-arm-static; \
	else \
		echo '#!/bin/sh\n\ntrue' > /qemu-arm-static; \
	fi; \
	chmod a+x /qemu-arm-static

FROM arm32v7/ubuntu
COPY --from=qemu /qemu-arm-static /usr/bin/

ENV HOME /root
ENV DEBIAN_FRONTEND noninteractive
ENV TERM="xterm" LANG="C.UTF-8" LC_ALL="C.UTF-8" APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1

RUN \
# Install initial dependencies
    apt-get update && apt-get upgrade -y && apt-get install -y \
    systemd \
    wget \
    gnupg \
    dbus \
    udev \
    software-properties-common \
    vim \
    ntfs-3g && \
    systemctl set-default multi-user.target && \
# Add repositories
    add-apt-repository -y ppa:shevchuk/dnscrypt-proxy && \
# Install dependencies 
    apt-get update && apt-get install -y --option=Dpkg::Options::=--force-confdef \
    openvpn \
    transmission-daemon \
    dnscrypt-proxy && \
    systemctl enable openvpn@client
RUN \
# Install plex
    # wget -O plex.deb https://downloads.plex.tv/plex-media-server-new/1.18.5.2309-f5213a238/debian/plexmediaserver_1.18.5.2309-f5213a238_armhf.deb && \
    # dpkg --force-confdef -i plex.deb && \
    # systemctl enable plexmediaserver.service && \
# Clean 
    apt-get -y autoremove && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/* && \
    rm -rf /var/tmp/*

COPY transmission/settings.json /etc/transmission-daemon/settings.json
COPY plex/plexmediaserver /etc/default/plexmediaserver
COPY openvpn/client.conf /etc/openvpn/client.conf
COPY openvpn/update-resolv-conf /etc/openvpn/update-resolv-conf
COPY dnscrypt-proxy/* /etc/dnscrypt-proxy/
# RUN echo "nameserver 127.0.0.1 options edns0" > /etc/resolv.conf

EXPOSE 32400/tcp 3005/tcp 8324/tcp 32469/tcp 1900/udp 32410/udp 32412/udp 32413/udp 32414/udp 9091 1194 53
STOPSIGNAL SIGRTMIN+3

CMD ["/bin/bash", "-c", "exec /sbin/init --log-target=journal 3>&1"]