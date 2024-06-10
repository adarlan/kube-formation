FROM alpine:3.19

ENV TERRAFORM_RELEASE 1.8.2

RUN apk add bash curl aws-cli ansible openssh-client

# terraform
RUN curl -fsSL https://releases.hashicorp.com/terraform/${TERRAFORM_RELEASE}/terraform_${TERRAFORM_RELEASE}_linux_amd64.zip -o /tmp/terraform_linux_amd64.zip && \
    cd /tmp/ && \
    unzip terraform_linux_amd64.zip terraform && \
    mv terraform /usr/local/bin/terraform && \
    chmod +x /usr/local/bin/terraform && \
    rm -f terraform_linux_amd64.zip

# packer
RUN curl -fsSL https://releases.hashicorp.com/packer/1.11.0/packer_1.11.0_linux_amd64.zip -o /tmp/packer_linux_amd64.zip && \
    cd /tmp/ && \
    unzip packer_linux_amd64.zip packer && \
    mv packer /usr/local/bin/packer && \
    chmod +x /usr/local/bin/packer && \
    rm -f packer_linux_amd64.zip

ARG USER
ARG UID
ARG GID
ENV USER=$USER \
    UID=$UID \
    GID=$GID \
    HOME=/home/$USER
RUN adduser -D -h $HOME -s /bin/bash $USER
RUN chown -R $USER:$USER $HOME
USER $USER
