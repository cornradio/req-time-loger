#!/usr/bin/env bash
# 这里是 curl 命令占位符（支持多行，直接粘贴到两个 EOF 之间）
CMD_STR=$(cat <<'EOF'
curl 'http://xxx.com/api/readfile/1.txt' \ 
  -H 'Accept: */*' \
  -H 'comment: 举例这是我自己服务器上的文件1.txt' \
  -H 'Accept-Language: zh-CN,zh;q=0.9,en;q=0.8' \
  --insecure
EOF
)

set -euo pipefail

script_dir=$(cd -- "$(dirname "$0")" && pwd)
LOG_FILE="$script_dir/log.txt"

timestamp=$(date "+%Y-%m-%d %H:%M:%S")
start_ns=$(date +%s%N)

tmp_out=$(mktemp)
set +e
bash -c "$CMD_STR" >"$tmp_out" 2>&1
rc=$?
set -e

end_ns=$(date +%s%N)
duration_ms=$(( (end_ns - start_ns) / 1000000 ))

# 提取 URI（取命令中最后一个 http/https 链接）
uri=$(printf "%s" "$CMD_STR" | tr '\n' ' ' | grep -oE "https?://[^'\"[:space:]]+" | tail -n1 || true)

# 从输出中解析 HTTP 状态码（优先解析首个 HTTP/.. 行），并兼容包含“HTTP/1.1 200”即视为成功
http_code=$(grep -m1 -oE "HTTP/[0-9.]+ [0-9]{3}" "$tmp_out" | awk '{print $2}' || true)

is_200="false"
if grep -qE "HTTP/1\.1[[:space:]]+200" "$tmp_out"; then
  is_200="true"
elif [ "${http_code:-}" = "200" ]; then
  is_200="true"
fi

echo "[$timestamp] duration_ms=${duration_ms} uri=${uri:-unknown} is_200=${is_200}" >> "$LOG_FILE"

rm -f "$tmp_out"

exit $rc
