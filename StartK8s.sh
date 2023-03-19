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
sleep 1s
showM

#  stop filewalld 防火墙
systemctl disable filewalld
systemctl stop filewalld
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
iptables -F
setenforce 0
cat >> /etc/sysctl.conf <<-EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-arptables = 1
EOF
sysctl -p /etc/sysctl.conf
  
  
ps -ef | grep "yum" | awk '{print $2}' | xargs kill -9

# 网络是否连通
if ! ping -c1 -W1 www.baidu.com &> /dev/null
then
     echo "不能连接到网络，请检查网络是否正常!"
     exit 1
fi

#配置 yum源
touch /etc/yum.repos.d/CentOS-Basebak.repo
cat > /etc/yum.repos.d/CentOS-Basebak.repo <<-EOF
[base]
name=CentOS-$releasever
enabled=1
failovermethod=priority
baseurl=http://mirrors.cloud.aliyuncs.com/centos/$releasever/os/$basearch/
gpgcheck=1
gpgkey=http://mirrors.cloud.aliyuncs.com/centos/RPM-GPG-KEY-CentOS-7

[updates]
name=CentOS-$releasever
enabled=1
failovermethod=priority
baseurl=http://mirrors.cloud.aliyuncs.com/centos/$releasever/updates/$basearch/
gpgcheck=1
gpgkey=http://mirrors.cloud.aliyuncs.com/centos/RPM-GPG-KEY-CentOS-7

[extras]
name=CentOS-$releasever
enabled=1
failovermethod=priority
baseurl=http://mirrors.cloud.aliyuncs.com/centos/$releasever/extras/$basearch/
gpgcheck=1
gpgkey=http://mirrors.cloud.aliyuncs.com/centos/RPM-GPG-KEY-CentOS-7
EOF

cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=http://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=http://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg
   http://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

# yum源初始化
yum -y update
yum clean all
yum makecache
yum -y install net-tools vim lrzsz wget docker
ps -ef | grep "yum" | awk '{print $2}' | xargs kill -9


# upload k8s  !
# delete k8s init 删除依赖配置 
# yum remove -y kube* etcd
# all节点
yum -y install  kubeadm-1.20.4 kubelet-1.20.4 kubectl-1.20.4 --disableexcludes=kubernetes
if [ $? -ne 0 ]
then
     echo "安装Kubernetes失败，请检查网络设置."
     exit 2
fi
#docker init 初始话操作
yum -y install docker
sed -ri 's/selinux-enabled /selinux-enabled=false /' /etc/sysconfig/docker
sed -ri 's/ServiceAccount,//' /etc/kubernetes/apiserver
cat > /etc/docker/daemon.json <<-EOF
{ 
"registry-mirrors": ["https://ahna2ftk.mirror.aliyuncs.com"]
}
EOF

systemctl daemon-reload
systemctl start docker
if [ $? -ne 0 ]
then
     echo "docker启动失败，请查询配置文件是否正确 /etc/sysconfig/docker."
     exit 2
fi

#start k8s server
systemctl start kube-apiserver
systemctl start kube-controller-manager
systemctl start kube-scheduler
systemctl start kubelet
systemctl start kube-proxy
systemctl enable docker.service
systemctl enable kubelet.service


# kubernetes ReplicationController nginx
touch nginx-rc.yaml
cat > nginx-rc.yaml <<-EOF
apiVersion: v1
kind: ReplicationController
metadata:
  name: nginx-rc
  labels:
    app: nginx
spec:
  replicas: 5
  selector:
    app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
EOF


yum install *rhsm* -y
wget http://mirror.centos.org/centos/7/os/x86_64/Packages/python-rhsm-certificates-1.19.10-1.el7_4.x86_64.rpm
if [ $? -ne 0 ]
then
     echo "获取Rhsm安装失败，请尝试手动下载解决."
     exit 2
fi
rpm2cpio python-rhsm-certificates-1.19.10-1.el7_4.x86_64.rpm | cpio -iv --to-stdout ./etc/rhsm/ca/redhat-uep.pem | tee /etc/rhsm/ca/redhat-uep.pem
#docker pull registry.access.redhat.com/rhel7/pod-infrastructure:lates
echo "OK~ K8SStart kubectl create -f nginx-rc.yaml !"
systemctl restart docker


cat > kube-flannel.yml <<-EOF
---
kind: Namespace
apiVersion: v1
metadata:
  name: kube-flannel
  labels:
    pod-security.kubernetes.io/enforce: privileged
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: flannel
rules:
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - get
- apiGroups:
  - ""
  resources:
  - nodes
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - nodes/status
  verbs:
  - patch
- apiGroups:
  - "networking.k8s.io"
  resources:
  - clustercidrs
  verbs:
  - list
  - watch
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: flannel
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: flannel
subjects:
- kind: ServiceAccount
  name: flannel
  namespace: kube-flannel
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: flannel
  namespace: kube-flannel
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: kube-flannel-cfg
  namespace: kube-flannel
  labels:
    tier: node
    app: flannel
data:
  cni-conf.json: |
    {
      "name": "cbr0",
      "cniVersion": "0.3.1",
      "plugins": [
        {
          "type": "flannel",
          "delegate": {
            "hairpinMode": true,
            "isDefaultGateway": true
          }
        },
        {
          "type": "portmap",
          "capabilities": {
            "portMappings": true
          }
        }
      ]
    }
  net-conf.json: |
    {
      "Network": "10.244.0.0/16",
      "Backend": {
        "Type": "vxlan"
      }
    }
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: kube-flannel-ds
  namespace: kube-flannel
  labels:
    tier: node
    app: flannel
spec:
  selector:
    matchLabels:
      app: flannel
  template:
    metadata:
      labels:
        tier: node
        app: flannel
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: kubernetes.io/os
                operator: In
                values:
                - linux
      hostNetwork: true
      priorityClassName: system-node-critical
      tolerations:
      - operator: Exists
        effect: NoSchedule
      serviceAccountName: flannel
      initContainers:
      - name: install-cni-plugin
        image: docker.io/flannel/flannel-cni-plugin:v1.1.2
       #image: docker.io/rancher/mirrored-flannelcni-flannel-cni-plugin:v1.1.2
        command:
        - cp
        args:
        - -f
        - /flannel
        - /opt/cni/bin/flannel
        volumeMounts:
        - name: cni-plugin
          mountPath: /opt/cni/bin
      - name: install-cni
        image: docker.io/flannel/flannel:v0.21.3
       #image: docker.io/rancher/mirrored-flannelcni-flannel:v0.21.3
        command:
        - cp
        args:
        - -f
        - /etc/kube-flannel/cni-conf.json
        - /etc/cni/net.d/10-flannel.conflist
        volumeMounts:
        - name: cni
          mountPath: /etc/cni/net.d
        - name: flannel-cfg
          mountPath: /etc/kube-flannel/
      containers:
      - name: kube-flannel
        image: docker.io/flannel/flannel:v0.21.3
       #image: docker.io/rancher/mirrored-flannelcni-flannel:v0.21.3
        command:
        - /opt/bin/flanneld
        args:
        - --ip-masq
        - --kube-subnet-mgr
        resources:
          requests:
            cpu: "100m"
            memory: "50Mi"
        securityContext:
          privileged: false
          capabilities:
            add: ["NET_ADMIN", "NET_RAW"]
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: EVENT_QUEUE_DEPTH
          value: "5000"
        volumeMounts:
        - name: run
          mountPath: /run/flannel
        - name: flannel-cfg
          mountPath: /etc/kube-flannel/
        - name: xtables-lock
          mountPath: /run/xtables.lock
      volumes:
      - name: run
        hostPath:
          path: /run/flannel
      - name: cni-plugin
        hostPath:
          path: /opt/cni/bin
      - name: cni
        hostPath:
          path: /etc/cni/net.d
      - name: flannel-cfg
        configMap:
          name: kube-flannel-cfg
      - name: xtables-lock
        hostPath:
          path: /run/xtables.lock
          type: FileOrCreate
EOF

# all节点集群部署
echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> ~/.bash_profile
source ~/.bash_profile

#master 初始话操作
#kubeadm reset
#kubeadm init --image-repository registry.aliyuncs.com/google_containers   --kubernetes-version v1.20.4  --pod-network-cidr=10.244.0.0/16
#mkdir -p $HOME/.kube
#sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
#sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 安装配置flannel网络插件
# kubectl apply -f kube-flannel.yml
# master节点加入
# ...
# master 执行 
# kubeadm token create --print-join-command
# node 节点加入


# 测试验证即可
# kubectl create -f nginx-rc.yaml