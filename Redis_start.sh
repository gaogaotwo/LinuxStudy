#!/bin/bash
# 创建网卡 Redis集群 
docker network create redis --subnet 172.38.0.0/16
# 修改Redis配置
for port in $(seq 1 6); \
do \
mkdir -p /gaogaotwo/Mydata/redis/node-${port}/conf
touch /gaogaotwo/Mydata/redis/node-${port}/conf/redis.conf
cat > /gaogaotwo/Mydata/redis/node-${port}/conf/redis.conf << EOF
port 6379 
bind 0.0.0.0
cluster-enabled yes
cluster-config-file nodes.conf
cluster-node-timeout 5000 
cluster-announce-ip 172.38.0.1${port}
cluster-announce-port 6379
cluster-announce-bus-port 16379
appendonly yes
EOF
docker run -p 637${port}:6379 -p 1637${port}:16379 --name redis-${port} \
-v /gaogaotwo/Mydata/redis/node-${port}/data:/data \
-v /gaogaotwo/Mydata/redis/node-${port}/conf/redis.conf:/etc/redis/redis.conf \
-d --net redis --ip 172.38.0.1${port} redis:5.0.9-alpine3.11 redis-server /etc/redis/redis.conf; \
done

echo "Redis cluster is ok"
