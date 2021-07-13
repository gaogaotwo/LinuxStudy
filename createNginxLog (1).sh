#! /bin/bash
#
#该脚本用于产生随机ip的nignx access日志,用于ELK模拟分析日志
#

#必须指定日志文件
if [ $# -ne 1 ]
then
     echo "Error!"
     echo "use: $0  <logFile>"
     exit 1
fi

logFile=$1

while :
do
    
    #产生114.215 段的随机IP
    #ip=14.215.$(expr $RANDOM % 256).$(($RANDOM % 254+1))
    ip=14.215.22.$(($RANDOM % 254+1))

    export LANG=en_US.utf8
    #产生时间
    time=$(date '+%d/%B/%Y:%H:%M:%S %z')

    echo -n "${ip} - - [${time}]"  >> ${logFile} 
    echo ' "GET /index.html HTTP/1.1" 200 4 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/89.0.4389.114 Safari/537.36" "-"' >> ${logFile}

    usleep  10000
done

exit 0
