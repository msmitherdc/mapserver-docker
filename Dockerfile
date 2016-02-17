##
# msmitherdc/grid-cloudhub
#
# This creates an Ubuntu derived base image that installs the MAPSERVER_VERSION of MapServer
# Git checkout compiled with needed drivers.
#

# Ubuntu 14.04 Trusty Tahyr
FROM msmitherdc/grid-cloudhub:gdal-2.0.1

MAINTAINER Michael Smith <Michael.smith.erdc@gmail.com>

USER root

#Setup user
ARG UID
ARG GID
#RUN adduser --no-create-home --disabled-login msuser --uid $UID --gid $GID

ENV ORACLE_HOME=/opt/instantclient
ENV LD_LIBRARY_PATH=${ORACLE_HOME}:/usr/lib

RUN apt-get update && apt-get install -y --fix-missing --no-install-recommends build-essential ca-certificates curl wget \
    git libaio1 make cmake python-numpy python-dev python-software-properties software-properties-common  libc6-dev libfreetype6-dev \
    libcairo2-dev flex bison libfcgi-dev libxml2 libxml2-dev bzip2 apache2 apache2-threaded-dev  apache2-mpm-worker apache2 \
   && apt-get remove --purge -y $BUILD_PACKAGES  && rm -rf /var/lib/apt/lists/*

ARG MAPSERVER_VERSION
RUN cd /build && \
    git clone https://github.com/mapserver/mapserver.git mapserver && \
    cd /build/mapserver && \
    git checkout ${MAPSERVER_VERSION} \
    && mkdir /build/mapserver/build \
    && cd /build/mapserver/build \
    && cmake \
      -DCMAKE_BUILD_TYPE=Release \
      -DWITH_CLIENT_WFS=ON \
      -DWITH_CLIENT_WMS=ON \
      -DWITH_CURL=ON \
      -DWITH_GDAL=ON \
      -DWITH_GIF=ON \
      -DWITH_ICONV=ON \
      -DWITH_KML=ON \
      -DWITH_LIBXML2=ON \
      -DWITH_OGR=ON \
      -DWITH_ORACLESPATIAL=ON \
      -DWITH_POINT_Z_M=ON \
      -DWITH_PROJ=ON \
      -DWITH_SOS=ON  \
      -DWITH_THREAD_SAFETY=ON \
      -DWITH_WCS=ON \
      -DWITH_WFS=ON \
      -DWITH_WMS=ON \
      -DWITH_FCGI=OFF \
      -DWITH_FRIBIDI=OFF \
      -DWITH_CAIRO=OFF \
      -DWITH_POSTGRES=OFF \
      -DWITH_HARFBUZZ=OFF \
      -DWITH_POSTGIS=OFF \
      ..  \
    && make  \
    && make install \
    && ldconfig \
    && rm -Rf /build/mapserver

# Externally accessible data is by default put in /u02
WORKDIR /u02
VOLUME ["/u02"]

# Clean up
RUN  apt-get purge -y software-properties-common build-essential cmake ;\
 apt-get autoremove -y ; \
 apt-get clean ; \
 rm -rf /var/lib/apt/lists/partial/* /tmp/* /var/tmp/*

# Execute the gdal utilities as nobody, not root

# Enable these Apache modules
RUN  a2enmod actions cgi alias

RUN chmod o+x /usr/local/bin/mapserv
RUN ln -s /usr/local/bin/mapserv /usr/lib/cgi-bin/mapserv
RUN chmod 755 /usr/lib/cgi-bin

EXPOSE  80

ENV HOST_IP `ifconfig | grep inet | grep Mask:255.255.255.0 | cut -d ' ' -f 12 | cut -d ':' -f 2`

CMD apache2ctl -D FOREGROUND
