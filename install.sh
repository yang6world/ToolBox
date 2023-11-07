#!/bin/bash
    ipv4=$(curl -s https://ipv4.icanhazip.com/)
    ipv6=$(curl -s https://ipv6.icanhazip.com/)
    run_time=$(cat /proc/uptime| awk -F. '{run_days=$1 / 86400;run_hour=($1 % 86400)/3600;run_minute=($1 % 3600)/60;run_second=$1 % 60;printf("%d天%d时%d分%d秒",run_days,run_hour,run_minute,run_second)}')
    echo -----------------------------------------------
    echo -e "\033[32m 欢迎使用551工具箱\033[0m"
    echo -e "\033[32m 本机ipv4：\033[0m \033[33m"$ipv4"\033[0m"
    echo -e "\033[32m 本机ipv6：\033[0m \033[33m"$ipv6"\033[0m"
    echo -e "\033[32m 本机运行时间:\033[0m\033[0m \033[44m"$run_time"\033[0m"
    echo -----------------------------------------------
    #检查是否为root用户
    if [ $(id -u) != "0" ]; then
        echo -e "\033[31m 错误：请使用root用户运行此脚本！\033[0m"
        exit 1
    fi
    #检查是存在/etc/toolbox目录
    if [ ! -d "/etc/toolbox" ]; then
        read -p "检测到您没有安装551工具箱，是否安装？（y/n）" yn
        if [[ $yn == "y" || $yn == "Y" ]]; then
            mkdir /etc/toolbox
            wget https://toolbox.yserver.top/latest/tool.sh -O /etc/toolbox/tool.sh
            wget https://toolbox.yserver.top/latest/wordpress.yaml -O /etc/toolbox/wordpress.yaml
            wget https://toolbox.yserver.top/latest/php.ini -O /etc/toolbox/php.ini
            wget https://toolbox.yserver.top/latest/tls.sh -O /etc/toolbox/tls.sh
            wget https://toolbox.yserver.top/latest/docker.service -O /etc/toolbox/docker.service
            ln -s /etc/toolbox/tool.sh /usr/local/bin/toolbox
            chmod +x /etc/toolbox/tool.sh
            chmod +x /usr/local/bin/toolbox
            echo -e "\033[32m 安装成功！\033[0m"
            echo -e "\033[32m 输入\033[0m \033[33m/etc/toolbox/551.sh\033[0m \033[32m即可运行！\033[0m"
            exit 1
        fi
    else
        echo -e "\033[31m 你已安装\033[0m"
        echo -e "\033[31m 输入\033[0m \033[33mtoolbox\033[0m \033[31m即可运行！\033[0m"
        exit 1
    fi
