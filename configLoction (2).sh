#! /bin/bash
#
#该脚本用于自动生成代理配置文件,适用于DESTOON电商平台项目 Discuz论坛项目
#
#使用方法：
#1.将该configLotion.sh脚本拷贝到 项目代码数据目录下(共享存储目录)
#2.给予执行权  chmod a+x  ./configlocation.sh
#3.运行该脚本  ./configLocation.sh
#

#特别注意以下信息设置
#!!!!!请正确指定代理服务器IP 如果有多台代理服务 空格分隔 指定多个IP地址
proxyIP="192.168.110.99"
#!!!!!请正确指定代理服务器root用户的登陆密码
proxyPas="123456"
#!!!!!网站根目录
rootPath="/var/www/upl.com"
########################################################
if ! ping -c1 -W1 www.baidu.com &> /dev/null
then
     echo "不能连接到网络，请检查网络是否正常!"
     exit 1
fi

yum install -y sshpass.x86_64
if [ $? -ne 0 ]
then
     echo "安装sshpass失败，请尝试手动解决."
     exit 2
fi

#######################################################
cat > ./.proxy.conf << EOF
server {
    listen       80;
    server_name  www.cloud.com;
    charset utf-8;
    access_log  /var/log/nginx/proxy.access.log  main;

    location / {
        root   ${rootPath};
        index  index.html index.htm;

        proxy_pass   http://webServer;
        proxy_set_header X-Real-IP  \$remote_addr;
        proxy_set_header X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_redirect off;
        proxy_connect_timeout 30;
        proxy_send_timeout 15;
        proxy_read_timeout 15;
    }
    
    fastcgi_connect_timeout 30;
    fastcgi_send_timeout 30;
    fastcgi_read_timeout 30;
    fastcgi_buffer_size  64k;
    fastcgi_buffers 4 64k;
    fastcgi_busy_buffers_size 128k;
    fastcgi_temp_file_write_size 128k;

    location ~ \.(php|php5)\$  {
        root  ${rootPath};
        fastcgi_pass  phpServer;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include   fastcgi_params;
    }
EOF
#######################################################



for file in $(find ./ -name "index.php")
do
    path=${file#*.}
    path=$(echo $path | sed -s 's/index.php//')

    echo "    location = ${path} {"          >> ./.proxy.conf
    echo "        root  ${rootPath};"     >> ./.proxy.conf
    echo "        fastcgi_pass  phpServer;"  >> ./.proxy.conf
    echo "        fastcgi_index index.php;"  >> ./.proxy.conf
    echo "        include   fastcgi_params;" >> ./.proxy.conf
    echo '        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;' >> ./.proxy.conf
    echo "     }"  >> ./.proxy.conf
done

echo "}"  >> ./.proxy.conf

######################################################
for ser in ${proxyIP}
do
     sshpass -p "${proxyPas}"  ssh -o StrictHostKeyChecking=no  root@${proxyIP} "rm -rf /etc/nginx/conf.d/*"
     sshpass -p "${proxyPas}"  scp ./.proxy.conf   root@${proxyIP}:/etc/nginx/conf.d/proxy.conf
done
######################################################

echo "配置代理 Location 成功."

exit 0


