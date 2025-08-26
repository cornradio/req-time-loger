#!/usr/bin/env bash
# 这里是 curl 命令占位符（支持多行，直接粘贴到两个 EOF 之间）
CMD_STR=$(cat <<'EOF'
curl -I 'https://b.cornradio.org/' \
  -H 'accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7' \
  -H 'accept-language: zh-CN,zh;q=0.9,en;q=0.8' \
  -H 'cache-control: max-age=0' \
  -H 'priority: u=0, i' \
  -H 'user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36'
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

# 从输出中解析 HTTP 状态码（优先解析首个 HTTP/.. 行），兼容 HTTP/1.1 与 HTTP/2 以及 :status: 200 形式
http_code=$(grep -m1 -oE "HTTP/[0-9.]+[[:space:]][0-9]{3}" "$tmp_out" | awk '{print $2}' || true)
if [ -z "${http_code:-}" ]; then
  # 兼容 HTTP/2 可能出现的伪首部输出形式，如 ":status: 200"
  http_code=$(grep -m1 -oE ":status:[[:space:]]*[0-9]{3}" "$tmp_out" | grep -oE "[0-9]{3}" || true)
fi

is_200="false"
if grep -qE "HTTP/[0-9.]+[[:space:]]+200" "$tmp_out"; then
  is_200="true"
elif grep -qE ":status:[[:space:]]*200" "$tmp_out"; then
  is_200="true"
elif [ "${http_code:-}" = "200" ]; then
  is_200="true"
fi

echo "[$timestamp] duration_ms=${duration_ms} uri=${uri:-unknown} is_200=${is_200}" >> "$LOG_FILE"

rm -f "$tmp_out"

exit $rc
