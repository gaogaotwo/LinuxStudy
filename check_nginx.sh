#!/bin/bash
#检测Nginx 80 端口是否存活
netstat -nlpt | grep -w '80' & >>/dev/null

#检查上条语句是否执行成功，若成功了 -ne 相当于 不等于0 及此时80端口已经断开
if [ $? -ne 0 ];then
#这里就实现 VIP的漂移！
  systemctl stop keepalived
fi
exit 0
