#!/bin/bash
#wordpress
domain=$(cat /etc/toolbox/config.yaml | grep domain | awk '{print $2}')
ipv4=$(curl -s https://ipv4.icanhazip.com/)

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
function countdown() {
    local seconds=$1

    for ((i=seconds; i>=0; i--)); do
        printf "\r马上就好: %02d s" $i
        sleep 1
    done

    echo ""  # 换行以便下一个命令正常显示
}
function wordpress_install(){
domain_check
echo "开始安装"
cat > /etc/nginx/sites-enabled/wordpress<< EOF
    server {
        listen       80;
        server_name  $domain;

        location / {
           if (\$host !~* ^www) {
              set \$name_www www.\$host;
              rewrite ^(.*) https://\$name_www\$1 permanent;
           }
           proxy_pass  http://localhost:8080;
           proxy_redirect     off;
           proxy_set_header   Host \$host;
           proxy_set_header   X-Real-IP \$remote_addr;
           proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
           proxy_set_header   X-Forwarded-Host \$server_name;
           proxy_set_header   X-Forwarded-Proto https;
           proxy_set_header   Upgrade \$http_upgrade;
           proxy_set_header   Connection "upgrade";
           proxy_read_timeout 86400;
        }
    }
EOF
nginx_restart
mkdir -p /root/config/wordpress/config
cp /etc/toolbox/config/php.ini /root/config/wordpress/config/php.ini
docker-compose -f /etc/toolbox/stacks/wordpress.yaml up -d
ssl_cert
cat > /etc/nginx/sites-enabled/wordpress<< EOF
    server {
        listen  80;
        server_name  $domain;
        rewrite ^(.*) https://\$host\$1 permanent;
    }
    server {
        listen       443 ssl http2 default_server;
        server_name  $domain;
        ssl_certificate "/etc/ssl/$domain.cer";
        ssl_certificate_key "/etc/ssl/$domain.key";
        ssl_session_timeout  10m;
        ssl_prefer_server_ciphers on;
        client_max_body_size 300M;
        

        location / {
           proxy_pass  http://localhost:8080;
           proxy_redirect     off;
           proxy_set_header   Host \$host;
           proxy_set_header   X-Real-IP \$remote_addr;
           proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
           proxy_set_header   X-Forwarded-Host \$server_name;
           proxy_set_header   X-Forwarded-Proto https;
           proxy_set_header   Upgrade \$http_upgrade;
           proxy_set_header   Connection "upgrade";
           proxy_read_timeout 86400;
        }
    }
EOF
nginx_restart
#读秒30
countdown 30
cat >> /root/config/wordpress/wp-config.php<< EOF
define('FS_METHOD','direct');

define('FORCE_SSL_ADMIN', true);

if (strpos(\$_SERVER['HTTP_X_FORWARDED_PROTO'], 'https') !== false){
    \$_SERVER['HTTPS'] = 'on';
    \$_SERVER['SERVER_PORT'] = 443;
}
if (isset(\$_SERVER['HTTP_X_FORWARDED_HOST'])) {
    \$_SERVER['HTTP_HOST'] = \$_SERVER['HTTP_X_FORWARDED_HOST'];
}

define('WP_HOME','https://$domain/');
define('WP_SITEURL','https://$domain/');
EOF
docker-compose -f /etc/toolbox/stacks/wordpress.yaml restart
}
#$1为install则执行安装uninstall则执行卸载
case $1 in
    install)
        #提醒解析域名的名称
        echo -e "\033[32m 请将$domain 解析到你的服务器 \033[0m"
        #用户确认
        read -p "域名解析完成后请按回车键继续"  
        wordpress_install
        ;;
    uninstall)
        #对选项进行二次确认
        read -p "确定要卸载wordpress？这将删除你的所有配置文件[y/n]" answer
        if [ $answer == "y" ]; then
            echo "开始卸载"
            docker-compose -f /etc/toolbox/stacks/wordpress.yaml down
            rm -rf /root/config/wordpress
            rm -rf /etc/nginx/sites-enabled/wordpress
            nginx_restart
        else
            echo "卸载已取消"
        fi
        ;;
esac