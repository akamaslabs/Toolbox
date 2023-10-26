FROM ubuntu:20.04

ENV BUILD_USER_ID=199
ENV BUILD_USER=akamas
ARG DOCKER_GROUP_ID=200

RUN apt-get update &&\
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
    less \
    file \
    zip \
    unzip \
    sudo \
    iputils-ping \
    net-tools \
    dnsutils \
    telnet \
    netcat \
    postgresql-client \
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

RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

RUN wget https://github.com/AdoptOpenJDK/openjdk11-binaries/releases/download/jdk-11.0.10%2B9/OpenJDK11U-jdk_x64_linux_hotspot_11.0.10_9.tar.gz -O /opt/OpenJDK11U-jdk_x64_linux_hotspot_11.0.10_9.tar.gz && \
    cd /opt && tar xzf OpenJDK11U-jdk_x64_linux_hotspot_11.0.10_9.tar.gz && rm /opt/OpenJDK11U-jdk_x64_linux_hotspot_11.0.10_9.tar.gz && mv /opt/jdk-11.0.10+9/ /opt/jdk-11.0.10_9/ && ln -s /opt/jdk-11.0.10_9/ /opt/java

RUN pip3 install --upgrade pip && \
    pip3 install setuptools wheel kubernetes

RUN wget https://github.com/mikefarah/yq/releases/download/v4.33.3/yq_linux_amd64 &&\
    mv yq_linux_amd64 /usr/bin/yq &&\
    chmod +x /usr/bin/yq

RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

RUN curl -LO "https://dl.k8s.io/release/v1.23.16/bin/linux/amd64/kubectl" && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

RUN wget https://github.com/derailed/k9s/releases/download/v0.27.4/k9s_Linux_amd64.tar.gz && tar xfz k9s_Linux_amd64.tar.gz -C /usr/local/bin/ && \
    chmod 755 /usr/local/bin/k9s && rm -f k9s_Linux_amd64.tar.gz

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && sudo ./aws/install && rm -rf awscliv2.zip aws/

RUN echo "${BUILD_USER} ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers

RUN echo "export PATH=/opt/java/bin:$PATH\n" \
         "export KUBECONFIG=/work/.kube/config\n" \
         "alias k=kubectl" >> /home/${BUILD_USER}/.bashrc

RUN curl -o akamas_cli https://s3.us-east-2.amazonaws.com/akamas/cli/$(curl -s https://s3.us-east-2.amazonaws.com/akamas/cli/stable.txt)/linux_64/akamas && \
    mv akamas_cli /usr/local/bin/akamas && \
    chmod 755 /usr/local/bin/akamas

RUN curl -O https://s3.us-east-2.amazonaws.com/akamas/cli/$(curl -s https://s3.us-east-2.amazonaws.com/akamas/cli/stable.txt)/linux_64/akamas_autocomplete.sh && \
    mkdir -p /home/${BUILD_USER}/.akamas && \
    mv akamas_autocomplete.sh /home/${BUILD_USER}/.akamas && \
    chmod 755 /home/${BUILD_USER}/.akamas/akamas_autocomplete.sh && \
    chown ${BUILD_USER}:${BUILD_USER} /home/${BUILD_USER}/.akamas/akamas_autocomplete.sh && \
    echo ". /home/${BUILD_USER}/.akamas/akamas_autocomplete.sh\ncd /work" >> /home/${BUILD_USER}/.bashrc

ADD --chown=${BUILD_USER}:${BUILD_USER} files/akamasconf /home/${BUILD_USER}/.akamas/

RUN mkdir -p /var/run/sshd

ADD --chown=${BUILD_USER}:${BUILD_USER} files/README /home/${BUILD_USER}/README
ADD files/entrypoint.sh /
RUN chmod +x /entrypoint.sh
RUN mkdir -p /work/.kube && chown -R ${BUILD_USER}:${BUILD_USER} /work
RUN ln -s /work/.kube/ /home/${BUILD_USER}/.kube && chown ${BUILD_USER}:${BUILD_USER} /home/akamas/.kube/
RUN mkdir -p /work/.ssh && chown -R ${BUILD_USER}:${BUILD_USER} /work
RUN ln -s /work/.ssh/ /home/${BUILD_USER}/.ssh && chown ${BUILD_USER}:${BUILD_USER} /home/akamas/.ssh/

USER ${BUILD_USER}

ENTRYPOINT bash /entrypoint.sh
SHELL ["/bin/bash", "-l", "-c"]