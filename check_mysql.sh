#!/bin/bash
#判断mysqld是否存活
netstat  -nlpt | grep -w '3306'  &>> /dev/null

#如果数据库不存活
if [ $? -ne 0 ]
then
   #停止keepalived服务使得通信中止，VIP则漂移到其他存活的Keepalived节点
   systemctl stop keepalived
fi
exit 0
