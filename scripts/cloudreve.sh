#!/bin/bash
ipv4=$(curl -s https://ipv4.icanhazip.com/)
domain=cloudreve.$(cat /etc/toolbox/config.yaml | grep domain | awk '{print $2}')
function domain_check(){
    echo -e "\033[32m 检查域名解析是否正确 \033[0m"
    ipv4s=`dig +short -t A $domain`
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
#cloudreve
function cloudreve_install(){
    domain_check
    echo -e "\033[32m 安装cloudreve \033[0m"
    mkdir -vp /root/config/cloudreve/{uploads,avatar} \
    && touch /root/config/cloudreve/conf.ini \
    && touch /root/config/cloudreve/cloudreve.db
    docker run -d \
    --name cloudreve \
    -p 5212:5212 \
    --mount type=bind,source=/root/config/cloudreve/conf.ini,target=/cloudreve/conf.ini \
    --mount type=bind,source=/root/config/cloudreve/cloudreve.db,target=/cloudreve/cloudreve.db \
    -v /root/config/cloudreve/uploads:/cloudreve/uploads \
    -v /root/config/cloudreve/avatar:/cloudreve/avatar \
    cloudreve/cloudreve:latest
    cat > /etc/nginx/sites-enabled/cloudreve<< EOF
    server {
        server_name $domain;
        charset utf-8;

        # dhparams file
        listen 80;

        location / {
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Host \$http_host;
        proxy_redirect off;
        proxy_pass http://127.0.0.1:5212;

        # 如果您要使用本地存储策略，请将下一行注释符删除，并更改大小为理论最大文件尺寸
        # client_max_body_size 20000m;
        }


    }

EOF
nginx_restart
ssl_cert

cat > /etc/nginx/sites-enabled/cloudreve<< EOF
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
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Host \$http_host;
        proxy_redirect off;
        proxy_pass http://127.0.0.1:5212;

        # 如果您要使用本地存储策略，请将下一行注释符删除，并更改大小为理论最大文件尺寸
        # client_max_body_size 20000m;
        }

    }

EOF
nginx_restart
}
#$1为install则执行安装uninstall则执行卸载
case $1 in
    install)
        cloudreve_install
    ;;
    uninstall)
    #对选项进行二次确认
        read -p "确定要卸载cloudreve？这将删除你的所有配置文件[y/n]" answer
        if [ $answer == "y" ]; then
            docker stop cloudreve
            docker rm cloudreve
            rm -rf /root/config/cloudreve
            rm -rf /etc/nginx/sites-enabled/cloudreve
            nginx_restart
        else
            echo "卸载已取消"
        fi
    ;;
esac