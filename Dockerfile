FROM ubuntu:20.04

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
    locales \
    vim \
    zip \
    unzip \
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

RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

RUN wget https://github.com/AdoptOpenJDK/openjdk11-binaries/releases/download/jdk-11.0.10%2B9/OpenJDK11U-jdk_x64_linux_hotspot_11.0.10_9.tar.gz -O /opt/OpenJDK11U-jdk_x64_linux_hotspot_11.0.10_9.tar.gz
RUN cd /opt && tar xzf OpenJDK11U-jdk_x64_linux_hotspot_11.0.10_9.tar.gz && rm /opt/OpenJDK11U-jdk_x64_linux_hotspot_11.0.10_9.tar.gz

RUN echo "export PATH=/opt/jdk-11.0.10_9/bin:$PATH" >> .bashrc

RUN pip3 install --upgrade pip

RUN pip3 install setuptools awscli boto boto3 botocore wheel

ARG BUILD_USER_ID=100
ARG BUILD_USER=root
ARG DOCKER_GROUP_ID=200
RUN groupdel docker && groupadd -g ${DOCKER_GROUP_ID} docker
RUN useradd --user-group --create-home --shell /bin/false -u ${BUILD_USER_ID} -G docker ${BUILD_USER}

RUN wget https://github.com/mikefarah/yq/releases/download/v4.33.3/yq_linux_amd64 &&\
    mv yq_linux_amd64 /usr/bin/yq &&\
    chmod +x /usr/bin/yq

RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

RUN curl -LO "https://dl.k8s.io/release/v1.23.16/bin/linux/amd64/kubectl" && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

RUN curl -o akamas_cli -O https://s3.us-east-2.amazonaws.com/akamas/cli/$(curl https://s3.us-east-2.amazonaws.com/akamas/cli/stable.txt)/linux_64/akamas && \
    mv akamas_cli /usr/local/bin/akamas && \
    chmod 755 /usr/local/bin/akamas
RUN curl -O https://s3.us-east-2.amazonaws.com/akamas/cli/$(curl https://s3.us-east-2.amazonaws.com/akamas/cli/stable.txt)/linux_64/akamas_autocomplete.sh && \
    mkdir -p ~/.akamas && \
    mv akamas_autocomplete.sh ~/.akamas && \
    echo '. ~/.akamas/akamas_autocomplete.sh' >> ~/.bashrc

USER ${BUILD_USER}
