#!/bin/bash

# Increase open files limit
echo '*       soft    nofile      4096' >> /etc/security/limits.conf
echo '*       hard    nofile      8192' >> /etc/security/limits.conf

# Upgrade packages and install ssh, vim
export DEBIAN_FRONTEND=noninteractive
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8
apt-get update --fix-missing
apt-get -q -y upgrade
apt-get -q -y install python-minimal openssh-server openssh-client vim postfix curl git atop sysstat screen unzip \
  tree xfsprogs awscli mdadm python3-pip jq apt-transport-https ca-certificates gnupg-agent software-properties-common \
  python-passlib
update-alternatives --set editor /usr/bin/vim.basic

# Secure postfix
perl -p -i -e "s/^inet_interfaces\s*=.*$/inet_interfaces=127.0.0.1/" /etc/postfix/main.cf

# install docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get -q -y install docker-ce docker-ce-cli containerd.io

# install docker-compose
pip3 install docker-compose

# install netdata
curl -Ss 'https://raw.githubusercontent.com/netdata/netdata-demo-site/master/install-required-packages.sh' >/tmp/kickstart.sh && bash /tmp/kickstart.sh -i netdata-all --non-interactive
bash <(curl -Ss https://my-netdata.io/kickstart.sh) --dont-wait


# Prepare cleanup
cat << EOF > /mnt/cleanup.sh
#!/bin/bash
apt-get clean
rm -f /etc/udev/rules.d/70-persistent*
rm -rf /var/lib/cloud/*
rm -rf /tmp/*
rm -rf /var/tmp/*
shred -u /root/.bash_history
shred -u /home/ubuntu/.bash_history
invoke-rc.d rsyslog stop
find /var/log -type f -exec rm {} \;
rm -f /etc/ssh/*key*
rm -rf /root/.ssh
rm -rf /home/ubuntu/.ssh
rm -rf /opt/microsoft
rm -rf /etc/apt/sources.list.d/microsoft.list
rm -rf /etc/apt/sources.list.d/microsoft-prod.list
shutdown -h now
EOF
chmod +x /mnt/cleanup.sh

# Wait for cloud-init to finish, run cleanup and stop instance
at -t $(date --date="now + 2 minutes" +"%Y%m%d%H%M") -f /mnt/cleanup.sh

