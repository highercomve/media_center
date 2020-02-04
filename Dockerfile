FROM alpine as qemu

RUN if [ -n "arm" ]; then \
		wget -O /qemu-arm-static https://github.com/multiarch/qemu-user-static/releases/download/v4.2.0-2/qemu-arm-static; \
	else \
		echo '#!/bin/sh\n\ntrue' > /qemu-arm-static; \
	fi; \
	chmod a+x /qemu-arm-static

FROM arm32v7/ubuntu

ARG S6_OVERLAY_VERSION=v1.22.1.0
COPY --from=qemu /qemu-arm-static /usr/bin/
COPY openvpn-restarter/openvpn-restarter /usr/bin/openvpn-restarter
COPY openvpn-restarter/openvpn-restarter.service /etc/init.d/openvpn-restarter
# COPY plex.deb plex.deb

ENV HOME /root
ENV DEBIAN_FRONTEND=noninteractive \
    TERM="xterm" \
    LANG="C.UTF-8" \
    LC_ALL="C.UTF-8" \
    PLEX_MEDIA_SERVER_USER=plex \
    PLEX_MEDIA_SERVER_TMPDIR=/home \
    PLEX_MEDIA_SERVER_INFO_MODEL=arm \
    PLEX_MEDIA_SERVER_INFO_DEVICE=PC \
    PLEX_MEDIA_SERVER_INFO_VENDOR=Ubuntu \
    PLEX_MEDIA_SERVER_MAX_PLUGIN_PROCS=6 \
    PLEX_MEDIA_SERVER_HOME=/usr/lib/plexmediaserver \
    PLEX_MEDIA_SERVER_INFO_PLATFORM_VERSION=MediaCenter \
    PLEX_MEDIA_SERVER_APPLICATION_SUPPORT_DIR="/var/lib/plexmediaserver/Library/Application Support" \
    LD_LIBRARY_PATH=/usr/lib/plexmediaserver/lib

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
    iputils-ping \
    usbmount \
    apt-utils \
    net-tools \
    module-init-tools \
    dnscrypt-proxy && \
    systemctl enable openvpn@client && \
    systemctl enable dnscrypt-proxy
RUN \
# Install plex
    wget -O plex.deb https://downloads.plex.tv/plex-media-server-new/1.18.0.1913-e5cc93306/debian/plexmediaserver_1.18.0.1913-e5cc93306_armhf.deb && \
    dpkg --force-confold  -i plex.deb && \
    # wget -q https://downloads.plex.tv/plex-keys/PlexSign.key -O - | apt-key add - && \
    # echo "deb https://downloads.plex.tv/repo/deb/ public main" > /etc/apt/sources.list.d/plexmediaserver.list && \
    # apt-get update && apt-get install -y --option=Dpkg::Options::=--force-confdef plexmediaserver && \
    systemctl enable plexmediaserver.service && \
# Clean 
    apt-get -y autoremove && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/* && \
    rm -rf /var/tmp/* && \
    mkdir /dev/net && \
    mknod /dev/net/tun c 10 200 && \
    chmod 666 /dev/net/tun && \
    chmod +x /usr/bin/openvpn-restarter && \
    chmod +x /etc/init.d/openvpn-restarter && \
    mv /usr/lib/plexmediaserver/Plex\ Media\ Server /usr/lib/plexmediaserver/PlexMediaServer && \
    rm plex.deb 

COPY transmission/settings.json /etc/transmission-daemon/settings.json
COPY plex-conf/plexmediaserver /etc/default/plexmediaserver
COPY plex-conf/plexmediaserver.service /lib/systemd/system/plexmediaserver.service
COPY openvpn/update-resolv-conf /etc/openvpn/update-resolv-conf
COPY dnscrypt-proxy/* /etc/dnscrypt-proxy/    

# RUN echo "nameserver 127.0.0.1 options edns0" > /etc/resolv.conf

EXPOSE 32400/tcp 3005/tcp 8324/tcp 32469/tcp 1900/udp 32410/udp 32412/udp 32413/udp 32414/udp 9091 1194 53
STOPSIGNAL SIGRTMIN+3

CMD ["/sbin/init"]