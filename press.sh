#!/bin/bash

# ========================================
# 配置区域 - 请在此处修改参数
# ========================================
THREAD_COUNT=10          # 并发线程数量
TOTAL_REQUESTS=100       # 总请求数量
CURL_COMMAND=$(cat <<'EOF'
# your curl command here
EOF
)

# ========================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 创建临时文件存储结果和统计
TEMP_FILE=$(mktemp)
STATS_FILE=$(mktemp)

# 全局变量，供信号处理函数使用
worker_pids=()

# 信号处理函数
cleanup() {
    echo -e "\n${YELLOW}正在清理资源，请稍候...${NC}"
    
    # 终止所有工作进程
    if [ ${#worker_pids[@]} -gt 0 ]; then
        for pid in "${worker_pids[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                kill -TERM "$pid" 2>/dev/null
                sleep 0.1
                if kill -0 "$pid" 2>/dev/null; then
                    kill -KILL "$pid" 2>/dev/null
                fi
            fi
        done
    fi
    
    # 清理临时文件
    rm -f "$TEMP_FILE" "$STATS_FILE" "${STATS_FILE}".*
    
    echo -e "${RED}测试已中断${NC}"
    exit 1
}

# 设置信号陷阱
trap cleanup INT TERM
trap "rm -f $TEMP_FILE $STATS_FILE ${STATS_FILE}.*" EXIT

# 初始化统计文件
touch "${STATS_FILE}.success"
touch "${STATS_FILE}.error"

# 日志函数
log_message() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" | tee -a $TEMP_FILE press-log.txt
}

# 显示配置信息
show_config() {
    echo -e "${YELLOW}压力测试配置:${NC}"
    echo "线程数量: $THREAD_COUNT"
    echo "总请求数: $TOTAL_REQUESTS"
    echo "Curl命令: $CURL_COMMAND"
    echo "----------------------------------------"
}

# 执行单个请求的函数
execute_request() {
    local request_id=$1
    
    # 执行curl命令并获取HTTP状态码和时间
    local result
    local http_code
    local time_total
    
    if [[ "$CURL_COMMAND" == *"-w"* ]]; then
        # 如果命令已经包含-w参数，添加时间输出
        result=$(eval "$CURL_COMMAND -w '%{http_code} %{time_total}' -o /dev/null" 2>/dev/null)
    else
        # 如果没有-w参数，添加状态码和时间输出
        result=$(eval "$CURL_COMMAND -w '%{http_code} %{time_total}' -o /dev/null" 2>/dev/null)
    fi
    
    # 解析结果
    http_code=$(echo "$result" | awk '{print $1}')
    time_total=$(echo "$result" | awk '{print $2}')
    
    # 转换为毫秒（curl返回的是秒）
    local duration
    if [ -n "$time_total" ] && [ "$time_total" != "0" ]; then
        duration=$(echo "$time_total * 1000" | bc -l 2>/dev/null | cut -d. -f1)
        if [ -z "$duration" ] || [ "$duration" = "0" ]; then
            duration=1
        fi
    else
        duration=1
    fi
    
        # 判断是否成功
    local is_success="false"
    if [[ "$http_code" =~ ^[23][0-9][0-9]$ ]]; then
        is_success="true"
        # 原子操作更新成功计数
        echo "$duration" >> "${STATS_FILE}.success"
    else
        # 原子操作更新失败计数
        echo "$duration" >> "${STATS_FILE}.error"
    fi
    
    # 提取域名用于日志显示
    local domain=""
    if [[ "$CURL_COMMAND" =~ https?://([^/[:space:]]+) ]]; then
        domain="${BASH_REMATCH[1]}"
    else
        domain="unknown"
    fi
    
    # 输出日志
    local log_line="duration_ms=${duration} uri=${domain} is_200=${is_success}"
    log_message "$log_line"
}

# 工作线程函数
worker() {
    local worker_id=$1
    local start_id=$2
    local end_id=$3
    
    for ((i=start_id; i<=end_id; i++)); do
        execute_request "$i"
    done
}

# 主函数
main() {
    echo -e "${GREEN}开始压力测试...${NC}"
    show_config
    
    # 计算每个线程处理的请求数量
    local requests_per_thread=$((TOTAL_REQUESTS / THREAD_COUNT))
    local remainder=$((TOTAL_REQUESTS % THREAD_COUNT))
    
    # 启动工作线程
    local current_id=1
    
    for ((i=1; i<=THREAD_COUNT; i++)); do
        local thread_requests=$requests_per_thread
        if [ $i -le $remainder ]; then
            ((thread_requests++))
        fi
        
        local end_id=$((current_id + thread_requests - 1))
        worker "$i" "$current_id" "$end_id" &
        worker_pids+=($!)
        current_id=$((end_id + 1))
    done
    
    # 等待所有工作线程完成
    for pid in "${worker_pids[@]}"; do
        wait "$pid" 2>/dev/null
    done
    
    # 计算统计结果
    local success_count=$(wc -l < "${STATS_FILE}.success" 2>/dev/null || echo "0")
    local error_count=$(wc -l < "${STATS_FILE}.error" 2>/dev/null || echo "0")
    
    # 计算总耗时
    local total_duration=0
    if [ -s "${STATS_FILE}.success" ]; then
        total_duration=$(awk '{sum+=$1} END {print sum}' "${STATS_FILE}.success" 2>/dev/null || echo "0")
    fi
    if [ -s "${STATS_FILE}.error" ]; then
        local error_duration=$(awk '{sum+=$1} END {print sum}' "${STATS_FILE}.error" 2>/dev/null || echo "0")
        total_duration=$((total_duration + error_duration))
    fi
    
    # 显示统计结果
    echo "----------------------------------------"
    echo -e "${GREEN}测试完成!${NC}"
    echo "总请求数: $TOTAL_REQUESTS"
    echo "成功请求: $success_count"
    echo "失败请求: $error_count"
    echo "总耗时: ${total_duration}ms"
    if [ $TOTAL_REQUESTS -gt 0 ]; then
        local avg_duration=0
        if [ $((success_count + error_count)) -gt 0 ]; then
            avg_duration=$((total_duration / (success_count + error_count)))
        fi
        echo "平均耗时: ${avg_duration}ms"
        echo "成功率: $((success_count * 100 / TOTAL_REQUESTS))%"
    fi
    
    # 显示日志文件位置
    echo "详细日志已保存到: $TEMP_FILE"
    echo "测试日志已保存到: press-log.txt"
}

# 检查依赖
check_dependencies() {
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}错误: 未找到curl命令${NC}"
        exit 1
    fi
    
    if ! command -v date &> /dev/null; then
        echo -e "${RED}错误: 未找到date命令${NC}"
        exit 1
    fi
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_dependencies
    main
fi
