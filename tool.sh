#!/bin/bash
version="1.1.2"
run_time=$(cat /proc/uptime| awk -F. '{run_days=$1 / 86400;run_hour=($1 % 86400)/3600;run_minute=($1 % 3600)/60;run_second=$1 % 60;printf("%d天%d时%d分%d秒",run_days,run_hour,run_minute,run_second)}')
if [ -f "/etc/toolbox/config.yaml" ]; then
    domain=$(cat /etc/toolbox/config.yaml | grep domain | awk '{print $2}')
    ipv4=$(curl -s https://ipv4.icanhazip.com/)
    ipv6=$(curl -s https://ipv6.icanhazip.com/)
    docker_api=$(cat /etc/toolbox/config.yaml | grep docker_api | awk '{print $2}')
    validator=$(cat /etc/toolbox/config.yaml | grep validator | awk '{print $2}')
    versions=$(cat /etc/toolbox/config.yaml | grep version | awk '{print $2}')
    vouch=$(cat /etc/toolbox/config.yaml | grep vouch | awk '{print $2}')
    docker_api_protect=$(cat /etc/toolbox/config.yaml | grep docker_api_protect | awk '{print $2}')
fi
#对比配置文件版本号
if [ "$version" != "$versions" ]; then
    modify_yaml_key /etc/toolbox/config.yaml version $version
fi
##查询本机位置
# 检查是否请求成功
response=$(curl -s http://ip-api.com/json/$ipv4)
if [ $? -eq 0 ]; then
  # 使用jq提取country值
  country=$(echo "$response" | jq -r '.countryCode')
else
  country="Unknown"
fi

#获取本机剩余内存
free_mem=$(free -m | awk '/Mem/ {print $7}')
free_disk=$(df -h | awk '/\/$/ {print $4}')
#获取当前docker版本
docker_version=$(docker -v | awk '{print $3}' | sed 's/,//g')
function graph_screen(){
    echo -----------------------------------------------------
    echo -e "\033[32m 欢迎使用551工具箱\033[0m \033[32m版本：\033[0m\033[44m"$version"\033[0m  \033[32mDocker版本：\033[0m\033[44m"$docker_version"\033[0m" 
    echo -e "\033[32m 本机ipv4：\033[0m \033[33m"$ipv4"\033[0m \033[32m所在位置：\033[0m \033[33m"$country"\033[0m "
    if [ ! -n "$ipv6" ]; then
        echo -e "\033[32m 本机ipv6：\033[0m \033[33m未检测到ipv6\033[0m"
    else
        echo -e "\033[32m 本机ipv6：\033[0m \033[33m"$ipv6"\033[0m"
    fi
    if [ -f "/etc/toolbox/config.yaml" ]; then
        echo -e "\033[32m 你的域名为:$domain\033[0m"
        echo -e "\033[32m 你的配置目录为:\033[0m \033[33m/root/config\033[0m  \033[32mdocker_api:\033[0m \033[33m"$docker_api"\033[0m"
    fi
    echo -e "\033[32m 已运行:\033[0m\033[0m \033[44m"$run_time"\033[0m \033[32m剩余内存:\033[0m\033[0m \033[44m"$free_mem"M\033[0m \033[32m剩余磁盘:\033[0m\033[0m \033[44m"$free_disk"\033[0m"
    echo -----------------------------------------------------
}
function chack_update(){
    new_version=$(curl -s -L https://toolbox.yserver.top/version)
    #对比版本号检查更新
    if [ "$new_version" != "$version" ]; then
        echo -e "\033[32m 检测到新版本$new_version，是否更新？ \033[0m"
        read -p "输入y更新，输入n跳过：" update
        if [ "$update" = "y" ]; then
            update_toolbox
        fi
    else
        echo -e "\033[32m 当前版本为最新版本 \033[0m"
    fi
}
function update_toolbox(){
    echo "正在更新"
    wget https://toolbox.yserver.top/latest/tool.sh -O /etc/toolbox/tool.sh
    wget https://toolbox.yserver.top/latest/wordpress.yaml -O /etc/toolbox/stacks/wordpress.yaml
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

#初始化
function first_start(){
    read -p "请输入你的域名（如xxx.yserver.top）：" domain
    echo -e "\033[32m 正在进行一些准备工作\033[0m"
    apt-get update > /dev/null
    apt-get install -y curl wget nginx sudo jq > /dev/null
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
    #检查是否存在配置文件
    if [ ! -f "/etc/toolbox/config.yaml" ]; then
        export password=$domain
        password=$domain
        cat <<EOF > /etc/toolbox/config.yaml
version: $version
domain: $domain
vouch: false
docker_api: true
docker_api_protect: false
validator: null
EOF
        mkdir -p /etc/toolbox
        cp ./* /etc/toolbox/
        ln -s /etc/toolbox/tool.sh /usr/local/bin/toolbox
        chmod +x /etc/toolbox/tool.sh
        chmod +x /usr/local/bin/toolbox
    fi
    docker_api=$(cat /etc/toolbox/config.yaml | grep docker_api | awk '{print $2}')
    #检查docker_api是否开启
    if [ "$docker_api" = "true" ]; then
        #是否开启端口2376
        if [ !  -n "$(lsof -i:2376)"  ]; then
            echo "未检测到证书"
            chmod +x /etc/toolbox/tls.sh
            bash /etc/toolbox/tls.sh
            systemctl stop docker 
            rm /lib/systemd/system/docker.service
            cp /etc/toolbox/config/docker.service-api /lib/systemd/system/docker.service
            sudo systemctl daemon-reload
            sudo systemctl restart docker.service
        else
            echo "docker_api已开启"
        fi
    fi


}
function advanced_options(){
    graph_screen
    if [ "$docker_api" = "true" ]; then
        echo -e "\033[31m 1.关闭docker_api \033[0m"
    else
        echo -e "\033[32m 1.开启docker_api \033[0m"
    fi
    if [ "$vouch" = "true" ]; then
        echo -e "\033[31m 2.关闭vouch \033[0m"
    else
        echo -e "\033[32m 2.开启vouch \033[0m"
    fi
    echo -e "\033[32m 3.重新生成TLS证书 \033[0m"
    echo -e "\033[32m 4.修改域名 \033[0m"
    if [ "$docker_api_protect" = "true" ]; then
        echo -e "\033[31m 5.关闭docker_api守护 \033[0m"
    else
        echo -e "\033[32m 5.开启docker_api守护 \033[0m"
    fi
    if [ "$vouch" = "true" ]; then
        echo -e "\033[32m 6.选择身份验证器（OIDC） \033[0m"
    fi
    echo -e "\033[32m 点击任意键返回上一级 \033[0m"
    read choice3
    case "$choice3" in
    1)
        if [ "$docker_api" = "true" ]; then
            echo "你选择了关闭docker_api"
            modify_yaml_key /etc/toolbox/config.yaml docker_api false
            systemctl stop docker 
            rm /lib/systemd/system/docker.service
            cp /etc/toolbox/config/docker.service /lib/systemd/system/docker.service
            sudo systemctl daemon-reload
            sudo systemctl restart docker.service
        else
            echo "你选择了开启docker_api"
            modify_yaml_key /etc/toolbox/config.yaml docker_api true
            systemctl stop docker 
            rm /lib/systemd/system/docker.service
            cp /etc/toolbox/config/docker.service-api /lib/systemd/system/docker.service
            sudo systemctl daemon-reload
            sudo systemctl restart docker.service
        fi
        ;;
    2)
        if [ "$vouch" = "true" ]; then
            echo "你选择了关闭vouch"
            modify_yaml_key /etc/toolbox/config.yaml vouch false
        else
            echo "你选择了开启vouch"
            modify_yaml_key /etc/toolbox/config.yaml vouch true
        fi
        ;;
    3)
        echo "你选择了重新生成TLS证书"
        chmod +x /etc/toolbox/tls.sh
        bash /etc/toolbox/tls.sh
        ;;
    4)
        echo "你选择了修改域名"
        read -p "请输入你的域名（如xxx.yserver.top）：" domain
        modify_yaml_key /etc/toolbox/config.yaml domain $domain
        ;;
    5)
        echo "你选择了选择保护器"
        ;;
    6)
        if [ "$docker_api_protect" = "true" ]; then
            echo "你选择了关闭docker_api守护"
            modify_yaml_key /etc/toolbox/config.yaml docker_api_protect false
        else
            echo "你选择了开启docker_api守护"
            modify_yaml_key /etc/toolbox/config.yaml docker_api_protect true
        fi
        ;;
    *)
        perview
        ;;
    esac
}



function install_app(){
    graph_screen
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
    if [ ! -f "/etc/nginx/sites-enabled/cloudreve" ]; then
        echo -e "\033[32m 4.安装cloudreve(你的个人云网盘) \033[0m"
    else
        echo -e "\033[31m 4.卸载cloudreve \033[0m"
    fi
    #判断用户输入
    read choice
    case "$choice" in
    1)
      if [ ! -f "/etc/nginx/sites-enabled/wordpress" ]; then
        echo "你选择了安装wordpress"
        chmod +x /etc/toolbox/scripts/wordpress.sh
        bash /etc/toolbox/scripts/wordpress.sh install
      else
        echo "你选择了卸载wordpress"
        chmod +x /etc/toolbox/scripts/wordpress.sh
        bash /etc/toolbox/scripts/wordpress.sh uninstall
      fi
      ;;
    2)
      if [ ! -f "/etc/nginx/sites-enabled/vscode" ]; then
        echo "你选择了安装vscode"
        chmod +x /etc/toolbox/scripts/vscode.sh
        bash /etc/toolbox/scripts/vscode.sh install
      else
        echo "你选择了卸载vscode"
        chmod +x /etc/toolbox/scripts/vscode.sh
        bash /etc/toolbox/scripts/vscode.sh uninstall
      fi
      ;;
    3) 
      if [ ! -f "/etc/nginx/sites-enabled/chatgpt" ]; then
        echo "你选择了安装chatGPT"
        chmod +x /etc/toolbox/scripts/chatgpt.sh
        bash /etc/toolbox/scripts/chatgpt.sh install
      else
        echo "你选择了卸载chatGPT"
        chmod +x /etc/toolbox/scripts/chatgpt.sh
        bash /etc/toolbox/scripts/chatgpt.sh uninstall
      fi
      ;;
    4)
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
      perview
      ;;
    esac
}
function perview(){
    graph_screen
    file="/etc/toolbox/config.yaml"
    if [ ! -f "$file" ]; then
        first_start
    fi
    if [ !  -n "$(cat /etc/toolbox/config.yaml | grep docker_api | awk '{print $2}')" ]; then
    cat <<EOF >> /etc/toolbox/config.yaml
docker_api: true
EOF
    fi
    chack_update
    export password=$domain
    password=$domain
    echo -e "\033[32m 1.安装/卸载应用服务 \033[0m"
    echo -e "\033[32m 2.列出应用详细信息 \033[0m"
    echo -e "\033[32m 3.服务器管理 \033[0m"
    echo -e "\033[32m 4.高级选项 \033[0m"
    echo -e "\033[32m 5.更新工具箱 \033[0m"
    echo -e "\033[32m 点击任意键退出 \033[0m"
    read choice1
    case "$choice1" in
    1)
        install_app
        ;;
    2)
        echo -e
        ;;
    3)
        graph_screen
        echo -e "\033[32m 1.重启服务器 \033[0m"
        echo -e "\033[32m 2.重启docker \033[0m"
        echo -e "\033[32m 3.重启nginx \033[0m"
        echo -e "\033[32m 点击任意键返回上一级 \033[0m"
        read choice2
        case "$choice2" in
        1)
            echo -e "\033[32m 重启服务器 \033[0m"
            reboot
            ;;
        2)
            echo -e "\033[32m 重启docker \033[0m"
            systemctl restart docker
            ;;
        3)
            echo -e "\033[32m 重启nginx \033[0m"
            nginx_restart
            ;;
        *)
            perview
            ;;
        esac
        ;;
    4)
        echo -e "\033[32m 敬请期待 \033[0m"

        ;;
    5)
        echo -e "\033[32m 更新工具箱 \033[0m"
        chack_update
        ;;
    esac
}
perview

