#!/bin/bash

yum -y install gcc
yum -y install gcc-c++
yum remove docker \docker-client \ docker-client-latest \ docker-common \ docker-latest \ docker-latest-logrotate \ docker-logrotate \ docker-engine
yum -y install  yum-utils
yum -y makecache fast
yum -y install docker
mkdir -p /etc/docker
touch /etc/docker/daemon.json
cat > /etc/docker/daemon.json<<-EOF
{
  "registry-mirrors": ["https://ahna2ftk.mirror.aliyuncs.com"]
}
EOF
systemctl daemon-reload
systemctl restart docker
mv /gaogaotwo/docker-compose /usr/local/bin #注意更名 权限 
sudo chmod +x /usr/local/bin/docker-compose