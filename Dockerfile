FROM ubuntu:20.04

ENV BUILD_USER_ID=199
ENV BUILD_USER=akamas
ARG DOCKER_GROUP_ID=200

RUN  apt-get update &&\
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    apt-transport-https \
    build-essential \
    ca-certificates \
    curl \
    gnupg2 \
    gnupg \
    lsb-release \
    software-properties-common \
    python3 \
    python3-pip \
    git \
    jq \
    libxml2-utils \
    openssh-client \
    openssh-server \
    sshpass \
    locales \
    vim \
    zip \
    unzip \
    sudo \
    iputils-ping \
    net-tools \
    dnsutils \
    telnet \
    netcat \
    wget && \
    apt-get autoremove -y && apt-get clean -y

RUN ln -s /usr/bin/python3 /usr/bin/python

#Setup docker repo
RUN  mkdir -p /etc/apt/keyrings &&\
     curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg &&\
     echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
#Install docker
RUN apt-get update &&\
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends\
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-compose-plugin && \
    apt-get autoremove -y && apt-get clean -y

RUN groupdel docker && groupadd -g ${DOCKER_GROUP_ID} docker
RUN useradd --user-group --create-home --shell /bin/bash -u ${BUILD_USER_ID} -G sudo,docker ${BUILD_USER} && newgrp docker
RUN build_password=$(openssl rand -hex 8) && echo $build_password > /tmp/akamas_password && chown ${BUILD_USER}:${BUILD_USER} /tmp/akamas_password && echo "${BUILD_USER}:${build_password}" | chpasswd


RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

RUN wget https://github.com/AdoptOpenJDK/openjdk11-binaries/releases/download/jdk-11.0.10%2B9/OpenJDK11U-jdk_x64_linux_hotspot_11.0.10_9.tar.gz -O /opt/OpenJDK11U-jdk_x64_linux_hotspot_11.0.10_9.tar.gz
RUN cd /opt && tar xzf OpenJDK11U-jdk_x64_linux_hotspot_11.0.10_9.tar.gz && rm /opt/OpenJDK11U-jdk_x64_linux_hotspot_11.0.10_9.tar.gz && mv /opt/jdk-11.0.10+9/ /opt/jdk-11.0.10_9/ && ln -s /opt/jdk-11.0.10_9/ /opt/java

RUN pip3 install --upgrade pip

RUN pip3 install setuptools awscli boto boto3 botocore wheel

RUN wget https://github.com/mikefarah/yq/releases/download/v4.33.3/yq_linux_amd64 &&\
    mv yq_linux_amd64 /usr/bin/yq &&\
    chmod +x /usr/bin/yq

RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

RUN curl -LO "https://dl.k8s.io/release/v1.23.16/bin/linux/amd64/kubectl" && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

RUN curl -o akamas_cli -O https://s3.us-east-2.amazonaws.com/akamas/cli/$(curl https://s3.us-east-2.amazonaws.com/akamas/cli/stable.txt)/linux_64/akamas && \
    mv akamas_cli /usr/local/bin/akamas && \
    chmod 755 /usr/local/bin/akamas

ADD --chown=${BUILD_USER}:${BUILD_USER} files/README /home/${BUILD_USER}/README
ADD files/entrypoint.sh /
RUN chmod +x /entrypoint.sh
RUN mkdir -p /home/${BUILD_USER}/.ssh && chown ${BUILD_USER}:${BUILD_USER} /home/${BUILD_USER}/.ssh
ADD --chown=${BUILD_USER}:${BUILD_USER} files/id_rsa.pub /home/${BUILD_USER}/.ssh/authorized_keys
RUN chmod 600 /home/${BUILD_USER}/.ssh/authorized_keys
RUN mkdir -p /work/.kube && chown -R ${BUILD_USER}:${BUILD_USER} /work
RUN ln -s /work/.kube/ /home/akamas/.kube && chown ${BUILD_USER}:${BUILD_USER} /home/akamas/.kube/
RUN echo "${BUILD_USER} ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers

RUN echo "export PATH=/opt/java/bin:$PATH" >> /home/${BUILD_USER}/.bashrc
RUN echo "export KUBECONFIG=/work/.kube/config" >> /home/${BUILD_USER}/.bashrc

RUN curl -O https://s3.us-east-2.amazonaws.com/akamas/cli/$(curl https://s3.us-east-2.amazonaws.com/akamas/cli/stable.txt)/linux_64/akamas_autocomplete.sh && \
    mkdir -p /home/${BUILD_USER}/.akamas && \
    mv akamas_autocomplete.sh /home/${BUILD_USER}/.akamas && \
    chmod 755 /home/${BUILD_USER}/.akamas/akamas_autocomplete.sh && \
    chown ${BUILD_USER}:${BUILD_USER} /home/${BUILD_USER}/.akamas/akamas_autocomplete.sh && \
    echo ". /home/${BUILD_USER}/.akamas/akamas_autocomplete.sh" >> /home/${BUILD_USER}/.bashrc

ADD --chown=${BUILD_USER}:${BUILD_USER} files/akamasconf /home/${BUILD_USER}/.akamas/

RUN if [ ! -f "/etc/ssh/ssh_host_rsa_key" ]; then ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa; fi
RUN ssh-keygen -f /etc/ssh/ssh_host_dsa_key -N '' -t dsa
RUN mkdir -p /var/run/sshd

USER ${BUILD_USER}
WORKDIR /home/${BUILD_USER}

ENTRYPOINT ["/entrypoint.sh"]
SHELL ["/bin/bash", "-l", "-c"]
