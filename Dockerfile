##
# msmitherdc/grid-cloudhub
#
# This creates an Ubuntu derived base image that installs the MAPSERVER_VERSION of MapServer
# Git checkout compiled with needed drivers. 
#

# Ubuntu 14.04 Trusty Tahyr
FROM msmitherdc/grid-cloudhub:gdal-2.0.1

MAINTAINER Michael Smith <Michael.smith.erdc@gmail.com>

# Set up Instant Client - already available from source image
#COPY instantclient_12_1 /opt/instantclient/

#Setup user
ARG UID
ARG GID 
RUN sudo adduser --no-create-home --disabled-login gdaluser --uid $UID --gid $GID

ENV ORACLE_HOME=/opt/instantclient 
ENV LD_LIBRARY_PATH=${ORACLE_HOME}:/usr/lib 

ARG MAPSERVER_VERSION
RUN cd /build && \
    git clone git@github.com:mapserver/mapserver.git mapserver && \
    cd /build/mapserver && \
    git checkout ${MAPSERVER_VERSION}

RUN cd /build/mapserver \
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
    && sudo make install \
    && ldconfig        

# Externally accessible data is by default put in /u02
WORKDIR /u02
VOLUME ["/u02"]

# Clean up
RUN sudo apt-get purge -y software-properties-common build-essential cmake ;\
 apt-get autoremove -y ; \
 apt-get clean ; \
 rm -rf /var/lib/apt/lists/partial/* /tmp/* /var/tmp/*

# Execute the gdal utilities as nobody, not root
USER msuser
