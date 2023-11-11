#!/bin/bash
#chatgpt
ipv4=$(curl -s https://ipv4.icanhazip.com/)
domain=gpt.$(cat /etc/toolbox/config.yaml | grep domain | awk '{print $2}')
domain_vouch=auth.$(cat /etc/toolbox/config.yaml | grep domain | awk '{print $2}')
vouch=$(cat /etc/toolbox/config.yaml | grep vouch | awk '{print $2}')
universal_password=$(cat /etc/toolbox/config.yaml | grep universal_password | awk '{print $2}')
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
function chatgpt_web_install_vouch(){
domain_check
echo -e "\033[32m 安装的chatgpt可使用单点认证 \033[0m"
read -p "输入你的api——key：" gpt_key
read -p "输入你的url：" gpt_url
docker run --name chatgpt-web -d -p 3002:3002 \
  --env OPENAI_API_KEY=$gpt_key \
  --env OPENAI_API_BASE_URL=$gpt_url \
  --env MAX_REQUESTS_PER_HOUR=0 \
  --env OPENAI_API_MODEL=gpt-3.5-turbo-16k \
  chenzhaoyu94/chatgpt-web
echo -e "\033[32m 安装完成默认使用GPT3.5 \033[0m"
cat > /etc/nginx/sites-enabled/chatgpt<< EOF
    server {
        server_name $domain;
        charset utf-8;

        # dhparams file
        listen 80;

        location / {
           # proxy_set_header   X-Real-IP \$remote_addr;
            proxy_pass http://127.0.0.1:8443;
          proxy_http_version 1.1;
          proxy_set_header Host \$host;
          proxy_set_header Upgrade \$http_upgrade;
          proxy_set_header Connection upgrade;
          proxy_set_header Accept-Encoding gzip;

        }


    }

EOF
nginx_restart
ssl_cert

cat > /etc/nginx/sites-enabled/chatgpt<< EOF
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
                # send all requests to the `/validate` endpoint for authorization
        auth_request /validate;

        location = /validate {
        # forward the /validate request to Vouch Proxy
        proxy_pass http://127.0.0.1:9090/validate;

        # be sure to pass the original host header
        proxy_set_header Host \$http_host;

        # Vouch Proxy only acts on the request headers
        proxy_pass_request_body off;
        proxy_set_header Content-Length "";

        # optionally add X-Vouch-User as returned by Vouch Proxy along with the request
        auth_request_set \$auth_resp_x_vouch_user \$upstream_http_x_vouch_user;

        # these return values are used by the @error401 call
        auth_request_set \$auth_resp_jwt \$upstream_http_x_vouch_jwt;
        auth_request_set \$auth_resp_err \$upstream_http_x_vouch_err;
        auth_request_set \$auth_resp_failcount \$upstream_http_x_vouch_failcount;
        }

        # if validate returns `401 not authorized` then forward the request to the error401block
        error_page 401 = @error401;

        location @error401 {
            # redirect to Vouch Proxy for login
            return 302 https://$domain_vouch/login?url=\$scheme://\$http_host\$request_uri&vouch-failcount=\$auth_resp_failcount&X-Vouch-Token=\$auth_resp_jwt&error=\$auth_resp_err;
        }
        location / {
        proxy_pass http://127.0.0.1:3002;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header X-Vouch-User \$auth_resp_x_vouch_user;

        }


    }

EOF
nginx_restart
}

function chatgpt_web_install(){
domain_check
echo -e "\033[32m 安装的chatgpt可使用单点认证 \033[0m"
read -p "输入你的api——key：" gpt_key
read -p "输入你的url：" gpt_url
docker run --name chatgpt-web -d -p 3002:3002 \
  --env OPENAI_API_KEY=$gpt_key \
  --env OPENAI_API_BASE_URL=$gpt_url \
  --env MAX_REQUESTS_PER_HOUR=0 \
  --env AUTH_SECRET_KEY=$universal_password \
  --env OPENAI_API_MODEL=gpt-3.5-turbo-16k \
  chenzhaoyu94/chatgpt-web
echo -e "\033[32m 安装完成默认使用GPT3.5 \033[0m"
cat > /etc/nginx/sites-enabled/chatgpt<< EOF
    server {
        server_name $domain;
        charset utf-8;

        # dhparams file
        listen 80;

        location / {
           # proxy_set_header   X-Real-IP \$remote_addr;
            proxy_pass http://127.0.0.1:8443;
          proxy_http_version 1.1;
          proxy_set_header Host \$host;
          proxy_set_header Upgrade \$http_upgrade;
          proxy_set_header Connection upgrade;
          proxy_set_header Accept-Encoding gzip;

        }


    }

EOF
nginx_restart
ssl_cert

cat > /etc/nginx/sites-enabled/chatgpt<< EOF
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
        proxy_pass http://127.0.0.1:3002;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        }


    }

EOF
nginx_restart
}
#$1为install则执行安装uninstall则执行卸载
case $1 in
    install)
        #如果vouch为true
        if [ $vouch == "true" ]; then
            chatgpt_web_install_vouch
        else
            chatgpt_web_install
        fi
    ;;
    uninstall)
        #对选项进行二次确认
        read -p "确定要卸载CahtGPT-web？这将删除你的所有配置文件[y/n]" answer
        if [ $answer == "y" ]; then
            docker stop chatgpt-web
            docker rm chatgpt-web
            rm -rf /etc/nginx/sites-enabled/chatgpt
            nginx_restart
        else
            echo "卸载已取消"
        fi
    ;;
    vouch)
        if [ $vouch == "true" ]; then
            docker stop chatgpt-web
            docker rm chatgpt-web
            rm -rf /etc/nginx/sites-enabled/chatgpt
            nginx_restart
            chatgpt_web_install_vouch
        else
            docker stop chatgpt-web
            docker rm chatgpt-web
            rm -rf /etc/nginx/sites-enabled/chatgpt
            nginx_restart
            chatgpt_web_install
        fi
    ;;
esac