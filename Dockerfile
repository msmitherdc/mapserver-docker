FROM continuumio/miniconda3  as build

RUN apt-get update --fix-missing && \
    apt-get install -y \
        wget unzip bzip2 ca-certificates sudo curl git  \
        vim parallel time && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
SHELL ["/bin/bash", "-c"]


ENV BASH_ENV ~/.bashrc
SHELL ["/bin/bash", "-c"]
ENV PATH /opt/conda/bin:$PATH

ARG MAPSEVER_VERSION
ARG PYTHON_VERSION
# For Oracle Support - add and uncomment
# COPY instantclient-19.8.0.0.0-3.tar.bz2  /tmp/
# COPY mapserverplugins-7.6.4-hf484d3e_1.tar.bz2 /tmp

# Create the environment:

RUN  conda create --yes --quiet --name ms python=${PYTHON_VERSION} && \
     conda config --add channels conda-forge && \
     conda install  --yes conda-pack && \
     conda update --all && \
     #conda install -n ms /tmp/instantclient-19.8.0.0.0-3.tar.bz2 /tmp/mapserverplugins-7.6.4-hf484d3e_1.tar.bz2 && \
     conda install -n ms --yes  libaio mapserver=${MAPSERVER_VERSION}
     #conda clean -afy

RUN conda-pack -n ms -o /tmp/env.tar --ignore-missing-files && \
     mkdir /venv && cd /venv && tar xf /tmp/env.tar && \
     rm /tmp/env.tar

RUN /venv/bin/conda-unpack

FROM registry1.dso.mil/ironbank/opensource/python/python39:v3.9 as runtime
USER root

RUN rpm --import http://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-8
RUN dnf install -y  https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm

RUN dnf update -y \
  && dnf install -y \
  httpd wget curl less time unzip zip lsof time procps-ng vim-enhanced glibc-langpack-en sudo \
  && dnf clean all

RUN echo 'LANG="en_US.utf8"' > /etc/locale.conf
RUN ln -s /usr/lib64/libnsl.so.2 /usr/lib64/libnsl.so.1

ENV CONDAENV /opt/conda/envs/ms
COPY --from=build /venv ${CONDAENV}

# Hack to work around problems with Proj.4 in Docker
ENV PROJ_LIB ${CONDAENV}/share/proj
ENV PROJ_NETWORK=TRUE
ENV PATH ${CONDAENV}/bin:$PATH
ENV DTED_APPLY_PIXEL_IS_POINT=TRUE
ENV GTIFF_POINT_GEO_IGNORE=TRUE
ENV GTIFF_REPORT_COMPD_CS=TRUE
ENV REPORT_COMPD_CS=TRUE
ENV OAMS_TRADITIONAL_GIS_ORDER=TRUE
ENV XDG_DATA_HOME=${CONDAENV}/share
ENV PROJ_CURL_CA_BUNDLE ${CONDAENV}/ssl/cacert.pem

SHELL ["/bin/bash", "-c"]
RUN source ${CONDAENV}/bin/activate &&  projsync --source-id us_nga && projsync --source-id us_noaa

ARG GID
ARG UID
RUN groupadd --gid $GID msgroup
#RUN adduser  --disabled-login msusr --gecos "" --uid $UID --gid $GID
RUN useradd msusr  --uid $UID --gid $GID
RUN echo "msusr ALL=NOPASSWD: ALL" >> /etc/sudoers
RUN ln -s ${CONDAENV}/bin/mapserv /var/www/cgi-bin
RUN printf ' \n\
<Directory "/var/www/cgi-bin"> \n\
    AllowOverride None \n\
    Options +ExecCGI -MultiViews -SymLinksIfOwnerMatch +FollowSymLinks \n\
    Require all granted \n\
</Directory> \n' > /etc/httpd/conf.d/ms.conf

USER msusr
WORKDIR /u02
ENTRYPOINT source ${CONDAENV}/bin/activate && sudo /usr/sbin/httpd -k start && bash
