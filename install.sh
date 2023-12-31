#!/bin/bash
    ipv4=$(curl -s https://ipv4.icanhazip.com/)
    ipv6=$(curl -s https://ipv6.icanhazip.com/)
    version_new=$(curl -s -L https://toolbox.yserver.top/version)
    version=$(cat /etc/toolbox/config.yaml | grep version | awk '{print $2}')
    run_time=$(cat /proc/uptime| awk -F. '{run_days=$1 / 86400;run_hour=($1 % 86400)/3600;run_minute=($1 % 3600)/60;run_second=$1 % 60;printf("%d天%d时%d分%d秒",run_days,run_hour,run_minute,run_second)}')
    echo -----------------------------------------------
    echo -e "\033[32m 欢迎使用551工具箱\033[0m"
    echo -e "\033[32m 本机ipv4：\033[0m \033[33m"$ipv4"\033[0m"
    if [ ! -n "$ipv6" ]; then
        echo -e "\033[32m 本机ipv6：\033[0m \033[33m未检测到ipv6\033[0m"
    else
        echo -e "\033[32m 本机ipv6：\033[0m \033[33m"$ipv6"\033[0m"
    fi
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
            wget https://toolbox.yserver.top/latest/toolbox.tar -O /tmp/toolbox.tar
            tar -xvf /tmp/toolbox.tar -C /etc/toolbox || tar -xvf --no-same-owner /tmp/toolbox.tar -C /etc/toolbox
            #若下载失败则退出
            if [ ! -f "/etc/toolbox/tool.sh" ]; then
                echo -e "\033[31m 安装失败！\033[0m"
                exit 1
            fi
            ln -s /etc/toolbox/tool.sh /usr/local/bin/toolbox
            chmod +x /etc/toolbox/tool.sh
            chmod +x /usr/local/bin/toolbox
            echo -e "\033[32m 安装成功！\033[0m"
            echo -e "\033[32m 输入\033[0m \033[33mtoolbox\033[0m \033[32m即可运行！\033[0m"
            exit 1
        fi
    else 
        if [ "$version_new" != "$version" ] ; then
            echo -e "\033[32m 检测到新版本$version_new，是否执行覆盖更新？（y/n）\033[0m"
            read -p "" yn
            if [[ $yn == "y" || $yn == "Y" ]]; then
                cp /etc/toolbox/config.yaml /tmp/config.yaml
                cp /etc/toolbox/config/chatgpt.yaml /tmp/chatgpt.yaml
                rm -rf /etc/toolbox
                rm -rf /usr/local/bin/toolbox
                mkdir /etc/toolbox
                wget https://toolbox.yserver.top/latest/toolbox.tar -O /tmp/toolbox.tar
                tar -xvf /tmp/toolbox.tar -C /etc/toolbox || tar -xvf --no-same-owner /tmp/toolbox.tar -C /etc/toolbox
                #若下载失败则退出
                if [ ! -f "/etc/toolbox/tool.sh" ]; then
                    echo -e "\033[31m 更新失败！\033[0m"
                    exit 1
                fi
                chmod +x /etc/toolbox/tool.sh
                ln -s /etc/toolbox/tool.sh /usr/local/bin/toolbox
                chmod +x /usr/local/bin/toolbox
                cp /tmp/chatgpt.yaml /etc/toolbox/config/chatgpt.yaml
                echo -e "\033[32m 更新成功！\033[0m"
                echo -e "\033[32m 输入\033[0m \033[33mtoolbox\033[0m \033[32m即可运行！\033[0m"
                exit 1
            fi
        else
            echo -e "\033[32m 您已安装最新版本！\033[0m"
            echo -e "\033[32m 输入\033[0m \033[33mtoolbox\033[0m \033[32m即可运行！\033[0m"
            exit 1
        fi
        
    fi
