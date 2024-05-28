FROM ubuntu:22.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV BUILD_USER_ID=199
ENV BUILD_USER=akamas
ARG DOCKER_GROUP_ID=200

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    apt-transport-https \
    build-essential \
    ca-certificates \
    curl \
    dnsutils \
    file \
    git \
    gnupg \
    gnupg2 \
    iputils-ping \
    jq \
    less \
    libxml2-utils \
    locales \
    lsb-release \
    net-tools \
    netcat \
    openssh-client \
    openssh-server \
    postgresql-client \
    python3 \
    python3-pip \
    software-properties-common \
    sshpass \
    sudo \
    telnet \
    unzip \
    vim \
    wget \
    zip && \
\
    ln -s /usr/bin/python3 /usr/bin/python && \
\
    mkdir -p /etc/apt/keyrings && \
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
\
    apt-get update && \
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-compose-plugin && \
    apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

RUN groupdel docker && groupadd -g ${DOCKER_GROUP_ID} docker
RUN useradd -l --user-group --create-home --shell /bin/bash -u ${BUILD_USER_ID} -G sudo,docker ${BUILD_USER} && newgrp docker

RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

ARG JAVA_VERSION=17.0.10+7
RUN wget -q "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-${JAVA_VERSION/+/%2B}/OpenJDK17U-jdk_x64_linux_hotspot_${JAVA_VERSION/+/_}.tar.gz" -O /opt/OpenJDK.tar.gz && \
    tar xzf /opt/OpenJDK.tar.gz -C /opt/ && rm /opt/OpenJDK.tar.gz && \
    mv "/opt/jdk-${JAVA_VERSION}" "/opt/jdk-${JAVA_VERSION/+/_}/" && ln -s "/opt/jdk-${JAVA_VERSION/+/_}/" /opt/java

RUN pip3 install --progress-bar off --no-cache-dir --upgrade pip && \
    pip3 install --progress-bar off --no-cache-dir setuptools wheel kubernetes

# link releases: https://github.com/mikefarah/yq/releases
RUN wget -q https://github.com/mikefarah/yq/releases/download/v4.41.1/yq_linux_amd64 && \
    mv yq_linux_amd64 /usr/bin/yq && \
    chmod +x /usr/bin/yq

RUN curl -sS https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# link releases: https://kubernetes.io/releases/
RUN curl -sS -LO "https://dl.k8s.io/release/v1.26.13/bin/linux/amd64/kubectl" && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# link releases: https://github.com/derailed/k9s/releases
RUN wget -q https://github.com/derailed/k9s/releases/download/v0.32.4/k9s_Linux_amd64.tar.gz && \
    tar xfz k9s_Linux_amd64.tar.gz -C /usr/local/bin/ && rm -f k9s_Linux_amd64.tar.gz && \
    chmod 755 /usr/local/bin/k9s

RUN curl -sS "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip -qq awscliv2.zip && ./aws/install && rm -rf awscliv2.zip aws/

RUN echo "${BUILD_USER} ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers && \
\
    echo "" >> /home/${BUILD_USER}/.bashrc && \
    echo "export PATH=/opt/java/bin:${PATH}" >> /home/${BUILD_USER}/.bashrc && \
    echo "export KUBECONFIG=/work/.kube/config" >> /home/${BUILD_USER}/.bashrc && \
    echo "alias k=kubectl" >> /home/${BUILD_USER}/.bashrc

RUN curl -sS -o akamas_cli https://s3.us-east-2.amazonaws.com/akamas/cli/2.9.0/linux_64/akamas && \
    mv akamas_cli /usr/local/bin/akamas && \
    chmod 755 /usr/local/bin/akamas && \
\
    curl -sS -O https://s3.us-east-2.amazonaws.com/akamas/cli/2.9.0/linux_64/akamas_autocomplete.sh && \
    mkdir -p /home/${BUILD_USER}/.akamas && \
    mv akamas_autocomplete.sh /home/${BUILD_USER}/.akamas && \
    chmod 755 /home/${BUILD_USER}/.akamas/akamas_autocomplete.sh && \
    chown ${BUILD_USER}:${BUILD_USER} /home/${BUILD_USER}/.akamas/akamas_autocomplete.sh && \
    echo "" >> /home/${BUILD_USER}/.bashrc && \
    echo ". /home/${BUILD_USER}/.akamas/akamas_autocomplete.sh" >> /home/${BUILD_USER}/.bashrc && \
    echo "cd /work" >> /home/${BUILD_USER}/.bashrc

COPY --chown=${BUILD_USER}:${BUILD_USER} files/akamasconf /home/${BUILD_USER}/.akamas/

RUN mkdir -p /var/run/sshd && \
    mkdir -p /home/${BUILD_USER}/.ssh /home/${BUILD_USER}/.sshd /work/.kube && \
    echo 'akamas' > /home/${BUILD_USER}/.factory_password && \
    echo "${BUILD_USER}:$(cat /home/${BUILD_USER}/.factory_password)" | chpasswd && \
    chown -R ${BUILD_USER}:${BUILD_USER} /home/${BUILD_USER} /work/
# On boot we'll need to update the password with a randomly-generated one. Since
# in kube envs we may not be able to `sudo`, and passwd doesn't work well without
# a password, we need to setup a default one

COPY files/entrypoint.sh /
RUN chmod +x /entrypoint.sh

USER ${BUILD_USER}

ENTRYPOINT ["bash", "/entrypoint.sh"]
SHELL ["/bin/bash", "-l", "-c"]
