FROM summerwind/actions-runner:ubuntu-24.04

USER root

RUN apt-get update && apt-get install -y \
    wget 
# gnupg

# Add GPG Keys
RUN wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list

RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    terraform \
    openssh-client \
    sshpass

RUN pip3 install --break-system-packages ansible infoblox-client jq yq pywinrm jmespath

RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

USER runner