#!/bin/bash
ipv4=$(curl -s https://ipv4.icanhazip.com/)
domain=unlockmusic.$(cat /etc/toolbox/config.yaml | grep domain | awk '{print $2}')
function domain_check(){
    echo -e "\033[32m 检查域名解析是否正确 \033[0m"
    ipv4s=`dig +short -t A $domain`|| ipv4s=`ping $domain -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
    #对比ipv4和ipv4s是否相同否则退出
    if [ "$ipv4" != "$ipv4s" ]; then
        echo -e "\033[31m 域名解析错误 \033[0m"
        exit 1
    fi

}
function ssl_cert(){
    echo "\033[32m 开始生成证书 \033[0m"
    acme.sh --issue  -d $domain  --nginx
    #检查证书是否生成成功
    acme.sh  --installcert  -d  $domain   \
            --key-file   /etc/ssl/$domain.key \
            --fullchain-file /etc/ssl/$domain.cer \
            --reloadcmd  "service nginx force-reload"
    if [ ! -f "/etc/ssl/$domain.key" ]; then
        echo "证书生成失败"
        exit 1
    fi

}
function nginx_restart(){
    echo -e "\033[32m 重启nginx \033[0m"
    service nginx restart
}

function netease_music_install(){
    echo -e "\033[32m 开始安装网易云音乐解锁 \033[0m"
    docker run -e JSON_LOG=true -p 8081:8080-e LOG_LEVEL=debug pan93412/unblock-netease-music-enhanced
}