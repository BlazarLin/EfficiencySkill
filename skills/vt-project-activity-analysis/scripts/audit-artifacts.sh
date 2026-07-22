#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

REPO="${1:-.}"
shift || true
cd "$REPO"
require_git_repo
parse_time_args "$@"

echo "========== 构建与解释器中间产物排查 =========="
echo "已排除目录规则: $IGNORED_DIR_REGEX"
echo "已排除文件规则: $IGNORED_FILE_REGEX"
echo ""

echo "========== 已被 Git 跟踪的中间产物 =========="
tracked=$(git ls-files | grep -Ei "$IGNORED_DIR_REGEX|$IGNORED_FILE_REGEX" || true)
if [ -n "$tracked" ]; then
    printf '%s\n' "$tracked"
else
    echo "无"
fi
echo ""

echo "========== 纳入贡献度统计的源码文件数 =========="
filtered_tracked_source_files | wc -l

echo "结论: 上述中间产物不会进入贡献度、分支活跃度或复杂度统计。"
