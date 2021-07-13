#!/bin/bash
#MHA manger节点IP
manger_ip="192.168.52.200"
#mha 管理mysql数据库的用户和密码
user="mha"
pas="Chenghao_123"
#用于同步的用户和密码
slave_user="admin"
slave_pas="Chenghao_123"
#MHA Manger配置文件
mha_conf="/etc/mha/app1.cnf"

###########################################################################
if [ $# -ne 1 ]
then
    echo "脚本使用错误!!!!!!"
    echo "使用方法:${0} <master IP>"
    exit 11
fi

master_ip=${1}


#检查数据据库是否已经启动
netstat  -nlpt | grep -w "mysqld" &> /dev/null
if [ $? -ne 0 ]
then
     echo "Mysqld server  not start."
     exit 1
fi

#从新 主库 备份数据
mysqldump -u${user} -p${pas} -h${master_ip} -B -A  >  /tmp/bak.sql
if [ $? -ne 0 ]
then
    echo "!!!!!!备份主库失败."
    exit 4
fi

#恢复
mysql -uroot -pChenghao_123  -e "set sql_log_bin=0;source /tmp/bak.sql;set sql_log_bin=1;"
if [ $? -ne 0 ]
then
    echo "!!!!!!!恢复数据失败."
    exit 2
fi
#####
mysql -uroot -pChenghao_123  -e "set global relay_log_purge=0;set global read_only=on;"

#连接主
values=($(mysql -u${user} -p${pas} -h${master_ip}  -e "show master status;" | grep "master" |awk '{print $1,$2}'))
mysql -uroot -pChenghao_123  -e "change master to master_host='${master_ip}',master_user='${slave_user}',master_password='${slave_pas}',master_log_file='${values[0]}',master_log_pos=${values[1]};start slave;"


ret=$(mysql -uroot -pChenghao_123 -e"show slave status\G" | grep -i "yes" | wc -l)
count=0
while [ ${ret} -ne 2 ]
do
    sleep 1
    ret=$(mysql -uroot -pChenghao_123 -e"show slave status\G" | grep -i "yes" | wc -l)
    let "count++"

    if [ ${count} -ge 3 ]
    then
         echo "!!!!!连接主库失败."
         exit 5
    fi
done

echo "数据库同步数据 及连接主库成功，可以解锁主库....."


####################处理MHA#######################################

ssh ${manger_ip}  "echo [server1]  >> ${mha_conf}"
ssh ${manger_ip}  "echo hostname=192.168.52.200  >> ${mha_conf}"
ssh ${manger_ip}  "echo port=3306  >> ${mha_conf}"

ssh ${manger_ip}  "masterha_check_ssh --conf=${mha_conf}"
if [ $? -ne 0 ]
then
     echo "!!!!!!!!!!!!!MHA Manger互信检查失败"
     exit 5
fi

ssh ${manger_ip}  "masterha_check_repl --conf=${mha_conf}"
if [ $? -ne 0 ]
then
     echo "!!!!!!!!!!!!!MHA Manger 主从机制检查失败"
     exit 6
fi

ssh ${manger_ip}  "nohup masterha_manager --conf=${mha_conf} --remove_dead_master_conf  --ignore_last_failover  < /dev/null>  /var/log/mha/app1/manager.log 2>&1 &"


#检查运行状态(因为mha启动需要做N多检查，因此需要一定的时间等待)
count=0
while :
do
   ssh ${manger_ip}  "masterha_check_status --conf=${mha_conf}"
   if [ $? -eq 0 ]
   then
      echo "MHA Start 成功,故障恢复完成!!!!!!!"
      exit 0
   fi

   let "count++"
   sleep 2

   if [ ${count} -ge 10 ]
   then
       break
   fi
done

echo "!!!!!!!MHA Start 失败."
exit 7
