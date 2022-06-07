#!/bin/bash

for i in $(ls -l /var/log/nginx/access*gz | awk '{print $9}');
do 
        Number=$(zcat $i | wc -l)
        Size=$(ls -l $i | awk '{print $5}')
        echo "$i 次数: $Number 大小: $Size"
done
