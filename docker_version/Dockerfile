FROM ubuntu:xenial-20161213

ARG DEBIAN_FRONTEND=noninteractive

# select swedish ubuntu archive mirror
RUN sed -i "s#http://archive#http://se.archive#g" /etc/apt/sources.list

RUN apt-get update && apt-get install -y \
    apt-transport-https \
    apt-utils \
    ca-certificates \
    software-properties-common \
    curl \
    wget \
    dialog \
    python \
    daemon \
    attr \
    vim \
    jq \
    && rm -rf /var/lib/apt/lists/*

# upgrade
RUN apt-get -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    upgrade \
    && rm -rf /var/lib/apt/lists/*

# remove unwanted systemd services
RUN for i in /lib/systemd/system/sysinit.target.wants/*; do [ "${i##*/}" = "systemd-tmpfiles-setup.service" ] || rm -f "$i"; done; \
    rm -f /lib/systemd/system/multi-user.target.wants/*;\
    rm -f /etc/systemd/system/*.wants/*;\
    rm -f /lib/systemd/system/local-fs.target.wants/*; \
    rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
    rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
    rm -f /lib/systemd/system/basic.target.wants/*;\
    rm -f /lib/systemd/system/anaconda.target.wants/*;
  
# install more (after removing unwanted systemd)

# Add Kubernetes repo..
RUN sh -c 'curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -'
RUN sh -c 'echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list'

# Add Docker repo..
RUN apt-key adv \
    --keyserver hkp://p80.pool.sks-keyservers.net:80 \
    --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
RUN sh -c 'echo "deb https://apt.dockerproject.org/repo ubuntu-xenial main" > /etc/apt/sources.list.d/docker.list'

# Add GlusterFS repo...
RUN add-apt-repository -y ppa:gluster/glusterfs-3.9

# Installing Kubernetes requirements...
RUN apt-get update -y && apt-get install -y \
  docker-engine=1.12.5-0~ubuntu-xenial \
  kubelet=1.5.2-00 \
  kubectl=1.5.2-00 \
  kubernetes-cni=0.3.0.1-07a8a2-00 \
  && rm -rf /var/lib/apt/lists/*
  
# Installing gluster etc...
RUN apt-get update -y && apt-get install -y \
    glusterfs-client \
    && rm -rf /var/lib/apt/lists/*
    
# Helm
ARG HELM_TGZ=helm-v2.1.0-linux-amd64.tar.gz
RUN wget -P /tmp/ https://kubernetes-helm.storage.googleapis.com/$HELM_TGZ \
    && tar -xf /tmp/$HELM_TGZ -C /tmp/ \
    && mv /tmp/linux-amd64/helm /usr/local/bin/ \
    && rm /tmp/$HELM_TGZ

# Create volume for docker
VOLUME /var/lib/docker


# -------- Some edits to install ssh - to make it Ansiable compliant -----

RUN mkdir -p /root/.ssh
#COPY key.pub /root/.ssh/authorized_keys

RUN apt-get update -y &&  apt-get install -y \
    openssh-server \
    && rm -rf /var/lib/apt/lists/*

RUN systemctl enable ssh

# -------- End ssh Ansible edits -----------------------------------------


RUN echo "Installing Kubeadm - this will fail at post-install but that doesn't matter"
RUN apt-get update -y && apt-get install -y \
    kubeadm=1.6.0-alpha.0-2074-a092d8e0f95f52-00; rm -rf /var/lib/apt/lists/*; exit 0

# Add other sock for Docker
RUN echo "DOCKER_HOST=unix:///var/tmp/docker.sock" >> /etc/environment



# -------- PULL docker images --------------------------------------------
#
# echo "Pulling required Docker images..."
# sudo docker pull \
#  kubenow/gluster-server:0.1.0
#
# ------------------------------------------------------------------------


