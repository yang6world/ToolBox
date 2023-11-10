#!/bin/bash
#docker_api_protect
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
docker_version=$(docker -v | awk '{print $3}' | sed 's/,//g')
docker_version_old=$(cat /etc/toolbox/config.yaml | grep docker_version | awk '{print $2}')
function protect_dockerapi(){
    #对比docker版本
    if [ "$docker_version" != "$docker_version_old" ] ; then
        systemctl stop docker 
        rm /lib/systemd/system/docker.service
        cp /etc/toolbox/config/docker.service-api /lib/systemd/system/docker.service
        sudo systemctl daemon-reload
        sudo systemctl restart docker.service
        modify_yaml_key /etc/toolbox/config.yaml docker_version $docker_version
    fi

}