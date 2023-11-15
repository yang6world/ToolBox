#!/bin/bash
#判断wordpress是否安装若安装则输出目录位置，占用内存，占用磁盘，运行时间信息
get_memory_usage() {
  local container_name="$1"
  # 获取容器的 ID
  local container_id=$(docker ps --filter "name=$container_name" --format "{{.ID}}")
  # 使用 docker stats 获取内存使用情况，并将输出存储到变量
  local stats_output=$(docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}")
  # 从输出中提取内存使用量（以变量 memory_usage 存储）
  local memory_usage=$(echo "$stats_output" | grep "$container_id" | awk '{print $2}')
  # 返回内存使用量
  echo "$memory_usage"
}
get_cpu_usage() {
  local container_name="$1"
  
  # 获取容器的 ID
  local container_id=$(docker ps --filter "name=$container_name" --format "{{.ID}}")

  # 使用 docker stats 获取 CPU 使用情况，并将输出存储到变量
  local stats_output=$(docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}")

  # 从输出中提取 CPU 使用百分比（以变量 cpu_usage 存储）
  local cpu_usage=$(echo "$stats_output" | grep "$container_id" | awk '{print $2}')

  # 返回 CPU 使用百分比
  echo "$cpu_usage"
}
function run_time(){
    local container_name="$1"
    local container_id=$(docker ps --filter "name=$container_name" --format "{{.ID}}")
    local run_time=$(docker inspect -f '{{.State.StartedAt}}' $container_id)
    echo $run_time
}
echo -----------------------------------------------------
#wordpress
echo -e "\033[32m 应用\033[0m       \033[32m 目录：\033[0m               \033[32m cpu占用\033[0m  \033[32m 内存占用\033[0m \033[32m     占用磁盘\033[0m    "
if [ -f "/etc/nginx/sites-enabled/wordpress" ]; then
    echo -e "\033[32m wordpress\033[0m  /root/config/wordpress  \033[32m$(get_cpu_usage "wordpress")\033[0m  \033[32m$(get_memory_usage "wordpress")\033[0m  \033[32m$(du -sh /root/config/wordpress | awk '{print $1}')\033[0m"
fi
#mysql
if [ -f "/etc/nginx/sites-enabled/mysql" ]; then
    echo -e "\033[32m mysql\033[0m      /root/config/mysql      \033[32m$(get_cpu_usage "db")\033[0m      \033[32m$(get_memory_usage "db")\033[0m       \033[32m$(du -sh /root/config/mysql | awk '{print $1}')\033[0m"
fi
#cloudreve
if [ -f "/etc/nginx/sites-enabled/cloudreve" ]; then
    echo -e "\033[32m cloudreve\033[0m  /root/config/cloudreve  \033[32m$(get_cpu_usage "cloudreve")\033[0m  \033[32m$(get_memory_usage "cloudreve")\033[0m  \033[32m$(du -sh /root/config/cloudreve | awk '{print $1}')\033[0m"
fi
#chatgpt
if [ -f "/etc/nginx/sites-enabled/chatgpt" ]; then
    echo -e "\033[32m chatgpt\033[0m    /root/config/chatgpt    \033[32m$(get_cpu_usage "chatgpt")\033[0m    \033[32m$(get_memory_usage "chatgpt")\033[0m    \033[32m$(du -sh /root/config/chatgpt | awk '{print $1}')\033[0m"
fi
#aria2
if [ -f "/etc/nginx/sites-enabled/aria2" ]; then
    echo -e "\033[32m aria2\033[0m      /root/config/aria2      \033[32m$(get_cpu_usage "aria2")\033[0m      \033[32m$(get_memory_usage "aria2")\033[0m       \033[32m$(du -sh /root/config/aria2 | awk '{print $1}')\033[0m"
fi
echo -----------------------------------------------------