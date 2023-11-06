#!/bin/bash
version="1.1.2"
if [ -f "/etc/toolbox/config.yaml" ]; then
    domain=$(cat /etc/toolbox/config.yaml | grep domain | awk '{print $2}')
    ipv4=$(curl -s https://ipv4.icanhazip.com/)
    ipv6=$(curl -s https://ipv6.icanhazip.com/)
fi
function update_toolbox(){
    echo "正在更新"
    wget https://toolbox.yserver.top/latest/tool.sh -O /etc/toolbox/tool.sh
    wget https://toolbox.yserver.top/latest/wordpress.yaml -O /etc/toolbox/wordpress.yaml
    chmod +x /etc/toolbox/tool.sh
    echo "更新完成，请重新运行"
    exit 0
}
#修改配置
modify_yaml_key() {
  local yaml_file="$1"
  local key_to_modify="$2"
  local new_value="$3"

  # 检查是否存在要修改的键
  if [[ -f "$yaml_file" ]]; then
    yaml_content=$(<"$yaml_file")

    if [[ $yaml_content == *"$key_to_modify:"* ]]; then
      # 使用正则表达式来查找要修改的键的行
      key_line=$(echo "$yaml_content" | grep -n "$key_to_modify:" | cut -d: -f1)
      # 计算缩进级别
      indent=$(echo "${yaml_content}" | sed -n "${key_line}p" | awk -F"$key_to_modify:" '{print $1}')
      # 替换键对应的值
      new_line="${indent}${key_to_modify}: $new_value"
      updated_yaml_content=$(echo "$yaml_content" | sed "${key_line}s/.*/$new_line/")
      # 保存更新后的内容回文件
      echo "$updated_yaml_content" > "$yaml_file"

      echo "配置已更新"
    else
      echo "未找到要修改的键: $key_to_modify"
    fi
  else
    echo "YAML 文件不存在: $yaml_file"
  fi
}
#倒计时
function countdown() {
    local seconds=$1

    for ((i=seconds; i>=0; i--)); do
        printf "\r马上就好: %02d s" $i
        sleep 1
    done

    echo ""  # 换行以便下一个命令正常显示
}
function nginx_restart(){
if sudo systemctl restart nginx; then
    echo "重启成功"
else
    echo "Nginx配置错误"
    exit 1
fi
}
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
#wordpress
function wordpress(){
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
docker-compose -f /etc/toolbox/wordpress.yaml up -d
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
cp /etc/toolbox/php.ini /root/config/wordpress/config/php.ini
docker-compose -f /etc/toolbox/wordpress.yaml restart
}
#代码服务器
function vscode(){
domains="$domain"
domain=vscode.$domain
domain_check
if [ -f "/etc/nginx/vouch" ]; then
    echo -e "\033[32m 安装的vscode将使用vouch认证 \033[0m"
fi
docker run -d \
  --name=code-server \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Asia/Shanghai \
  -e PROXY_DOMAIN=$domain  \
  -e DEFAULT_WORKSPACE=/config/workspace  \
  -p 8443:8443 \
  -v /root/config/vscode:/config \
  --restart unless-stopped \
  ghcr.io/yang6world/docker-code-server:main

cat > /etc/nginx/sites-enabled/vscode<< EOF
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

cat > /etc/nginx/sites-enabled/vscode<< EOF
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
domain=$domains
}
#chatgpt
function chatgpt_web(){
domains="$domain"
domain=gpt.$domain
domain_check
echo -e "\033[32m 安装的chatgpt可使用单点认证 \033[0m"
read -p "输入你的api——key：" gpt_key
read -p "输入你的url：" gpt_url
read -p "设置你的密码：" gpt_password
docker run --name chatgpt-web -d -p 127.0.0.1:3002:3002 --env OPENAI_API_KEY=$gpt_key  --evn OPENAI_API_BASE_URL=$gpt_url  --evn MAX_REQUEST_PER_HOUR=0 --evn AUTH_SECRET_KEY=$gpt_password --evn OPENAI_API_MODEL=gpt-3.5-turbo-16k  chenzhaoyu94/chatgpt-web
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
domain=$domains
}
#vouch
function vouch(){
    echo -e "\033[32m 敬请期待 \033[0m"
}
#cloudreve
function cloudreve(){
    domains="$domain"
    domain=cloud.$domain
    domain_check
    echo -e "\033[32m 安装cloudreve \033[0m"
    mkdir -vp /root/config/cloudreve/{uploads,avatar} \
    && touch /root/config/cloudreve/conf.ini \
    && touch /root/config/cloudreve/cloudreve.db
    docker run -d \
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
domain=$domains

}
#nonebot
function nonebot(){
    echo -e "\033[32m 敬请期待 \033[0m"
}
#初始化
function start(){
    read -p "请输入你的域名（如xxx.yserver.top）：" domain
    echo -e "\033[32m 正在进行一些准备工作\033[0m"
    apt-get update > /dev/null
    apt-get install -y curl wget nginx sudo > /dev/null
    if [ ! -x "$(command -v docker)" ]; then
        echo "未在系统中检测到docker环境"
        echo "开始安装docker"
        curl -fsSL https://get.docker.com | bash -s
    fi

    if [ ! -x "$(command -v docker)" ]; then
        echo "docker安装失败"
        exit 1
    fi
    #安装docker-compose
    if [ ! -x "$(command -v docker-compose)" ]; then
        sudo curl -L "https://github.com/docker/compose/releases/download/v2.2.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
    fi
    #检查docker-compose是否安装完成
    if [ ! -x "$(command -v docker-compose)" ]; then
        echo "docker-compose安装失败"
        exit 1
    fi
    #安装acme.sh
    if [ ! -x "$(command -v acme.sh)" ]; then
        curl https://get.acme.sh | sh 
        rm -rf /usr/local/bin/acme.sh
        ln -s  /root/.acme.sh/acme.sh /usr/local/bin/acme.sh
        acme.sh --set-default-ca --server letsencrypt
    fi
    #检查acme.sh是否安装完成
    if [ ! -x "$(command -v acme.sh)" ]; then
        echo "acme.sh安装失败"
        exit 1
    fi
    #检查是否存在toolbox
    file="/usr/local/bin/toolbox"

    if [ ! -f "$file" ]; then
        export password=$domain
        password=$domain
        cat <<EOF > /etc/toolbox/config.yaml
domain: $domain
vouch: false
EOF
        chmod +x ./tls.sh
        source ./tls.sh
        systemctl stop docker 
        rm /lib/systemd/system/docker.service
        cp ./docker.service /lib/systemd/system/docker.service
        sudo systemctl daemon-reload
        sudo systemctl restart docker.service
        mkdir -p /etc/toolbox
        cp ./* /etc/toolbox/
        ln -s /etc/toolbox/tool.sh /usr/local/bin/toolbox
        chmod +x /etc/toolbox/tool.sh
        chmod +x /usr/local/bin/toolbox
    fi

}

function perview(){
    echo -----------------------------------------------
    echo -e "\033[32m 欢迎使用551工具箱\033[0m  \033[32m 版本：\033[0m \033[44m"$version"\033[0m"
    echo -e "\033[32m 本机ipv4：\033[0m \033[44m"$ipv4"\033[0m"
    echo -e "\033[32m 本机ipv6：\033[0m \033[44m"$ipv6"\033[0m"
    if [ -f "/etc/toolbox/config.yaml" ]; then
        echo -e "\033[32m 你的域名为:$domain\033[0m"
        echo -e "\033[32m 你的配置目录为:\033[0m \033[33m/root/config\033[0m"
    fi
    echo ----------------------------------------------- 
    file="/etc/toolbox/config.yaml"
    if [ ! -f "$file" ]; then
        start
    fi
    new_version=$(curl -s -L toolbox.yserver.top/version)
    #对比版本号检查更新
    if [ "$new_version" != "$version" ]; then
        echo -e "\033[32m 检测到新版本$new_version，是否更新？ \033[0m"
        read -p "输入y更新，输入n跳过：" update
        if [ "$update" = "y" ]; then
            update_toolbox
        fi
    fi

    export password=$domain
    password=$domain
    echo -e "\033[32m 请选择安装 \033[0m"
    if [ ! -f "/etc/nginx/sites-enabled/wordpress" ]; then
        echo -e "\033[32m 1.安装wordpress \033[0m"
    else
        echo -e "\033[31m 1.卸载wordpress \033[0m"
    fi
    if [ ! -f "/etc/nginx/sites-enabled/vscode" ]; then
        echo -e "\033[32m 2.安装vscode \033[0m"
    else
        echo -e "\033[31m 2.卸载vscode \033[0m"
    fi
    if [ ! -f "/etc/nginx/sites-enabled/chatgpt" ]; then
        echo -e "\033[32m 3.安装chatGPT \033[0m"
    else
        echo -e "\033[31m 3.卸载chatGPT \033[0m"
    fi
    if [ ! -f "/etc/nginx/vouch" ]; then
        echo -e "\033[32m 4.安装vouch \033[0m"
    else
        echo -e "\033[31m 4.卸载vouch \033[0m"
    fi
    if [ ! -f "/etc/nginx/sites-enabled/cloudreve" ]; then
        echo -e "\033[32m 5.安装cloudreve(你的个人云网盘) \033[0m"
    else
        echo -e "\033[31m 5.卸载cloudreve \033[0m"
    fi
    #判断用户输入
    read choice
    case "$choice" in
    1)
      if [ ! -f "/etc/nginx/sites-enabled/wordpress" ]; then
        echo "你选择了安装wordpress"
        wordpress
      else
        echo "你选择了卸载wordpress"
        rm -rf /etc/nginx/sites-enabled/wordpress
        nginx_restart
        docker-compose -f /etc/toolbox/wordpress.yaml down
      fi
      ;;
    2)
      if [ ! -f "/etc/nginx/sites-enabled/vscode" ]; then
        echo "你选择了安装vscode"
        vscode
      else
        echo "你选择了卸载vscode"
        docker stop code-server
        docker rm -f code-server
        rm -rf /etc/nginx/sites-enabled/vscode
        nginx_restart
      fi
      ;;
    3) 
      if [ ! -f "/etc/nginx/sites-enabled/chatgpt" ]; then
        echo "你选择了安装chatGPT"
        chatgpt_web
      else
        echo "你选择了卸载chatGPT"
        docker stop chatgpt-web
        docker rm -f chatgpt-web
        rm -rf /etc/nginx/sites-enabled/chatgpt
        nginx_restart
      fi
      ;;
    4)
        if [ ! -f "/etc/nginx/vouch" ]; then
            echo "你选择了安装vouch"
            vouch
            modify_yaml_key /etc/toolbox/config.yaml vouch true
        else
            echo "你选择了卸载vouch"
            rm -rf /etc/nginx/vouch
            modify_yaml_key /etc/toolbox/config.yaml vouch false
            nginx_restart
        fi
        ;;
    5)
        if [ ! -f "/etc/nginx/sites-enabled/cloudreve" ]; then
            echo "你选择了安装cloudreve"
            cloudreve
        else
            echo "你选择了卸载cloudreve"
            docker stop cloudreve
            docker rm -f cloudreve
            rm -rf /etc/nginx/sites-enabled/cloudreve
            nginx_restart
        fi
        ;;
    *)
      echo "谢谢使用！"
      exit 0
      ;;
    esac
}
perview

