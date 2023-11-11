#!/bin/bash
ipv4=$(curl -s https://ipv4.icanhazip.com/)
domain=auth.$(cat /etc/toolbox/config.yaml | grep domain | awk '{print $2}')
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
function vouch_install(){
    domain_check
    echo -e "\033[32m 安装vouch \033[0m"
    mkdir -p /root/config/vouch
    echo -e "\033[33m 你将要创建vouch配置文件 \033[0m \033[31m 配置文件请参照 https://github.com/vouch/vouch-proxy \033[0m"
    sleep 5
    nano /root/config/vouch/config.yml
    if [ ! -f "/root/config/vouch/config.yml" ]; then
        echo "配置文件未创建"
        exit 1
    else
        echo "开始安装"
    fi
    docker run -d \
        -p 9090:9090 \
        --name vouch-proxy \
        --restart=always \
        -v /root/config/vouch:/config \
        quay.io/vouch/vouch-proxy
    cat > /etc/nginx/sites-enabled/vouch<< EOF
    server {
        server_name $domain;
        charset utf-8;

        # dhparams file
        listen 80;

        location / {
          proxy_pass http://127.0.0.1:9090;
          # be sure to pass the original host header
          proxy_set_header Host \$http_host;
        }
    }

EOF
    nginx_restart
    ssl_cert
    cat > /etc/nginx/sites-enabled/vouch<< EOF
server {
    # Setting vouch behind SSL allows you to use the Secure flag for cookies.
    listen 443 ssl http2;
    server_name $domain;

    ssl_certificate /etc/ssl/$domain.cer;
    ssl_certificate_key /etc/ssl/$domain.key;

    location / {
       proxy_pass http://127.0.0.1:9090;
       # be sure to pass the original host header
       proxy_set_header Host \$http_host;
    }
}
EOF
    nginx_restart
}
#$1为install则执行安装uninstall则执行卸载
case $1 in
    install)
        #提醒解析域名的名称
        echo -e "\033[32m 请将$domain 解析到你的服务器 \033[0m"
        #用户确认
        read -p "域名解析完成后请按回车键继续"  
        vouch_install
        #判断是否安装了chatgpt
        if [ -f "/etc/nginx/sites-enabled/chatgpt" ]; then
            chmod +x /etc/toolbox/scripts/app/chatgpt.sh 
            bash /etc/toolbox/scripts/app/chatgpt.sh vouch
        fi 
        #判断是否安装了vscode
        if [ -f "/etc/nginx/sites-enabled/vscode" ]; then
            chmod +x /etc/toolbox/scripts/app/vscode.sh 
            bash /etc/toolbox/scripts/app/vscode.sh vouch
        fi
    ;;
    uninstall)
        #对选项进行二次确认
        read -p "你确定要卸载vouch吗？[y/n]" answer
        if [ $answer != "y" ]; then
            exit 1
        fi
        docker rm -f vouch-proxy
        rm -rf /root/config/vouch
        rm -rf /etc/nginx/sites-enabled/vouch
        nginx_restart
        if [ -f "/etc/nginx/sites-enabled/chatgpt" ]; then
            chmod +x /etc/toolbox/scripts/app/chatgpt.sh 
            bash /etc/toolbox/scripts/app/chatgpt.sh vouch
        fi 
        #判断是否安装了vscode
        if [ -f "/etc/nginx/sites-enabled/vscode" ]; then
            chmod +x /etc/toolbox/scripts/app/vscode.sh
            bash /etc/toolbox/scripts/app/vscode.sh vouch
        fi
    ;;
esac