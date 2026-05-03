FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install OpenSSH server
RUN apt-get update && \
    apt-get install -y openssh-server sudo nano && \
    mkdir -p /var/run/sshd && \
    rm -rf /var/lib/apt/lists/*

# Set root password
RUN echo 'root:mmmm0987' | chpasswd

# Configure SSH
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    echo 'StrictModes no' >> /etc/ssh/sshd_config && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    echo 'PubkeyAuthentication yes' >> /etc/ssh/sshd_config

# Add SSH public key for root login
RUN mkdir -p /root/.ssh && \
    echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINl/8uY6DFHrP7QB/Nowv3oHceyUpq0QjL/lVLA45Vf7' > /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh && \
    chmod 600 /root/.ssh/authorized_keys

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D", "-e"]
