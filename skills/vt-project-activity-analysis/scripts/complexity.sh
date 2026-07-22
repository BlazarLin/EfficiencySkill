#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

REPO="${1:-.}"
shift || true
cd "$REPO"
require_git_repo
parse_time_args "$@"
command -v lizard >/dev/null 2>&1 || die "未安装 lizard；请先执行 pip install lizard"

TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT
filtered_tracked_source_files > "$TMPFILE"

echo "========== 圈复杂度分析 =========="
echo "仓库: $(pwd)"
echo "时间: $(time_label)（复杂度基于当前存活源码；时间范围用于报告标识）"
echo "分析文件数: $(wc -l < "$TMPFILE")"
echo ""

echo "========== 全局统计 =========="
lizard -C 15 -L 200 -f "$TMPFILE" | tail -20
echo ""

echo "========== 告警摘要 =========="
lizard -C 15 -L 200 -w -f "$TMPFILE" | grep 'warning:' || true
