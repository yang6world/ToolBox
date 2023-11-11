#!/bin/bash
ipv4=$(curl -s https://ipv4.icanhazip.com/)
domain=login.$(cat /etc/toolbox/config.yaml | grep domain | awk '{print $2}')
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
function logto_install(){
    domain_check
    echo -e "\033[32m 安装logto \033[0m"
    docker-compose -f /etc/toolbox/stacks/logto.yaml up -d
    mkdir -p /root/config/logto
    cat > /etc/nginx/sites-enabled/logto<< EOF
server {
  listen 80;
  server_name $domain; 

  location / {
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;

    proxy_pass http://127.0.0.1:3001;
  }

}
EOF
    nginx_restart
    ssl_cert
cat > /etc/nginx/sites-enabled/logto<< EOF
    server {
        listen 80;
        listen [::]:80;
        server_name $domain;

        # Enforce HTTPS
        return 301 https://\$server_name\$request_uri;
    }
    server {
        server_name $domain;
        charset utf-8;

        ssl_session_timeout 1d;
        ssl_session_cache shared:MozSSL:10m;
        ssl_session_tickets off;
        ssl_certificate /etc/ssl/$domain.cer;
        ssl_certificate_key /etc/ssl/$domain.key;

        # dhparams file
        listen 443 ssl http2;
    

        # intermediate configuration
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;

        location / {
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto https;

            proxy_pass http://127.0.0.1:3001;
        }


    }

EOF
cat > /etc/nginx/sites-enabled/logto_admin<< EOF
    server {
        listen 80;
        listen [::]:80;
        server_name $domain;

        # Enforce HTTPS
        return 301 https://\$server_name\$request_uri;
    }
    server {
        server_name $domain;
        charset utf-8;

        ssl_session_timeout 1d;
        ssl_session_cache shared:MozSSL:10m;
        ssl_session_tickets off;
        ssl_certificate /etc/ssl/$domain.cer;
        ssl_certificate_key /etc/ssl/$domain.key;

        # dhparams file
        listen 443 ssl http2;
    

        # intermediate configuration
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;

        location / {
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto https;

            proxy_pass http://127.0.0.1:3003;
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
        logto_install
        ;;
    uninstall)
        docker-compose -f /etc/toolbox/stacks/logto.yaml down
        rm -rf /etc/nginx/sites-enabled/logto
        rm -rf /etc/nginx/sites-enabled/logto_admin
        nginx_restart
        ;;
esac