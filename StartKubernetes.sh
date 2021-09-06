#!/bin/bash

showS(){
        echo "
 ______     ______     ______    
/\\  ___\\   /\\  __ \\   /\\  __ \\   
\\ \\ \\__ \\  \\ \\  __ \\  \\ \\ \\/\\ \\  
 \\ \\_____\\  \\ \\_\\ \\_\\  \\ \\_____\\ 
  \\/_____/   \\/_/\\/_/   \\/_____/ 

"
}
showM(){
        echo "                                          __                 
   _________    ____   _________    _____/  |___  _  ______  
  / ___\\__  \\  /  _ \\ / ___\\__  \\  /  _ \\   __\\ \\/ \\/ /  _ \\ 
 / /_/  > __ \\(  <_> ) /_/  > __ \\(  <_> )  |  \\     (  <_> )
 \\___  (____  /\\____/\\___  (____  /\\____/|__|   \\/\\_/ \\____/ 
/_____/     \\/      /_____/     \\
"
}
showS
showM

#  stop filewalld
systemctl disable filewalld
systemctl stop filewalld
iptables -F
setenforce 0


if ! ping -c1 -W1 www.baidu.com &> /dev/null
then
     echo "不能连接到网络，请检查网络是否正常!"
     exit 1
fi



# upload k8s  ! 
yum -y install etcd kubernetes
if [ $? -ne 0 ]
then
     echo "安装Kubernetes失败，请检查网络设置."
     exit 2
fi


sed -ri 's/selinux-enabled /selinux-enabled=false /' /etc/sysconfig/docker
sed -ri 's/ServiceAccount,//' /etc/kubernetes/apiserver

#docker init


cat > /etc/docker/daemon.json <<-EOF
{ 
"registry-mirrors": ["https://ahna2ftk.mirror.aliyuncs.com"]
}
EOF

systemctl daemon-reload

#start k8s
systemctl start etcd
systemctl start docker
if [ $? -ne 0 ]
then
     echo "docker启动失败，请查询配置文件是否正确 /etc/sysconfig/docker."
     exit 2
fi

systemctl start kube-apiserver
systemctl start kube-controller-manager
systemctl start kube-scheduler
systemctl start kubelet
systemctl start kube-proxy

touch mysql-rc.yaml
cat > mysql-rc.yaml <<-EOF
apiVersion: v1
kind: ReplicationController
metadata:
  name: mysql
spec:
  replicas: 1
  selector:
    app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql 
        ports:
        - containerPort: 3306
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "123456"
EOF

yum install *rhsm* -y
wget http://mirror.centos.org/centos/7/os/x86_64/Packages/python-rhsm-certificates-1.19.10-1.el7_4.x86_64.rpm
if [ $? -ne 0 ]
then
     echo "获取Rhsm安装失败，请尝试手动解决."
     exit 2
fi

rpm2cpio python-rhsm-certificates-1.19.10-1.el7_4.x86_64.rpm | cpio -iv --to-stdout ./etc/rhsm/ca/redhat-uep.pem | tee /etc/rhsm/ca/redhat-uep.pem
docker pull registry.access.redhat.com/rhel7/pod-infrastructure:latest

echo "OK~ K8SStart kubectl create -f mysql-rc.yaml !"
