#!/bin/bash
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
base_model=$(cat /etc/toolbox/config/chatgpt.yaml | grep base_model | awk -F 'base_model: ' '{print $2}')
base_url=$(cat /etc/toolbox/config/chatgpt.yaml | grep base_url | awk -F 'base_url: ' '{print $2}')
api_key=$(cat /etc/toolbox/config/chatgpt.yaml | grep api_key | awk -F 'api_key: ' '{print $2}')
function graph_screen(){
    echo -----------------------------------------------------
    echo -e "\033[32m ChatGPT应用\033[0m " 
    echo -e "\033[32m api地址为：\033[0m \033[33m $base_url \033[0m"
    echo -e "\033[32m api_key为：\033[0m \033[33m $api_key \033[0m"
    echo -e "\033[32m 基础模型为：\033[0m \033[33m $base_model \033[0m"
    echo -----------------------------------------------------
}
function set_model(){
    #可选择的模型有gpt-3.5-turbo-16k，gpt-3.5-turbo，gpt-4，gpt-4-32k，gpt-4-1106-preview
    graph_screen
    echo -e "\033[32m 请选择模型：\033[0m "
    echo -e "\033[32m 1. gpt-3.5-turbo-16k\033[0m "
    echo -e "\033[32m 2. gpt-3.5-turbo\033[0m "
    echo -e "\033[32m 3. gpt-4\033[0m "
    echo -e "\033[32m 4. gpt-4-32k\033[0m "
    echo -e "\033[32m 5. gpt-4-1106-preview\033[0m "
    echo -e "\033[32m 6. 自定义\033[0m "
    read -p "请输入序号：" model
    case $model in
        1)
        modify_yaml_key /etc/toolbox/config/chatgpt.yaml base_model gpt-3.5-turbo-16k
        ;;
        2)
        modify_yaml_key /etc/toolbox/config/chatgpt.yaml base_model gpt-3.5-turbo
        ;;
        3)
        modify_yaml_key /etc/toolbox/config/chatgpt.yaml base_model gpt-4
        ;;
        4)
        modify_yaml_key /etc/toolbox/config/chatgpt.yaml base_model gpt-4-32k
        ;;
        5)
        modify_yaml_key /etc/toolbox/config/chatgpt.yaml base_model gpt-4-1106-preview
        ;;
        6)
        read -p "请输入模型名称：" model_name
        modify_yaml_key /etc/toolbox/config/chatgpt.yaml base_model $model_name
        ;;
        *)
        echo -e "\033[31m 输入错误！\033[0m"
        ;;
    esac
}
function set_api(){
    graph_screen
    read -p "请输入api地址：" api_url
    modify_yaml_key /etc/toolbox/config/chatgpt.yaml base_url $api_url
}
function set_key(){
    graph_screen
    read -p "请输入api_key：" api_key
    modify_yaml_key /etc/toolbox/config/chatgpt.yaml api_key $api_key
}
#调整配置后重新安装
function reinstall(){
    if [ -f "/etc/nginx/sites-enabled/chatgpt" ]; then
        chmod +x /etc/toolbox/scripts/app/chatgpt.sh
        bash /etc/toolbox/scripts/app/chatgpt.sh reinstall
    fi
    if [ -f "/etc/nginx/sites-enabled/chatgpt_next" ]; then
        chmod +x /etc/toolbox/scripts/app/chatgpt_2.sh
        bash /etc/toolbox/scripts/app/chatgpt_2.sh reinstall
    fi
}
function init(){
    read -p "请输入api地址：" api_url
    read -p "请输入api_key：" api_key
    cat <<EOF > /etc/toolbox/config/chatgpt.yaml
base_url: $api_url
api_key: $api_key
base_model: null
EOF
    set_model
}
if [ ! -f "/etc/toolbox/config/chatgpt.yaml" ]; then
    init
fi
function start(){
graph_screen
echo -e "\033[32m 请选择要执行的操作：\033[0m "
#1.安装chatgpt-web 2.安装chatgpt-next 3.设置
echo -e "\033[32m 1. 安装chatgpt-web项目\033[0m "
echo -e "\033[32m 2. 安装chatgpt-next项目\033[0m "
echo -e "\033[32m 3. 设置\033[0m "
read -p "请输入序号：" num
case $num in
    1) 
        if [ ! -f "/etc/nginx/sites-enabled/chatgpt" ]; then
          echo "你选择了安装chatGPT"
          chmod +x /etc/toolbox/scripts/app/chatgpt.sh
          bash /etc/toolbox/scripts/app/chatgpt.sh install
        else
          echo "你选择了卸载chatGPT"
          chmod +x /etc/toolbox/scripts/app/chatgpt.sh
          bash /etc/toolbox/scripts/app/chatgpt.sh uninstall
        fi
        ;;
    2)
        if [ ! -f "/etc/nginx/sites-enabled/chatgpt_next" ]; then
          echo "你选择了安装chatGPT-next"
          chmod +x /etc/toolbox/scripts/app/chatgpt_2.sh
          bash /etc/toolbox/scripts/app/chatgpt_2.sh install
        else
          echo "你选择了卸载chatGPT-next"
          chmod +x /etc/toolbox/scripts/app/chatgpt_2.sh
          bash /etc/toolbox/scripts/app/chatgpt_2.sh uninstall
        fi
        ;;  
    3)
        graph_screen
        echo -e "\033[32m 请选择要执行的操作：\033[0m "
        echo -e "\033[32m 1. 设置api地址\033[0m "
        echo -e "\033[32m 2. 设置api_key\033[0m "
        echo -e "\033[32m 3. 设置模型\033[0m "
        echo -e "\033[32m 任意键返回上一级\033[0m "
        read -p "请输入序号：" num
        case $num in
            1) 
                set_api
                reinstall
                ;;
            2)
                set_key
                reinstall
                ;;
            3)
                set_model
                reinstall
                ;;
            *)
                start
        esac
        ;;
    *)
        toolbox
        ;;
esac
}