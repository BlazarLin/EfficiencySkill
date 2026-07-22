#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

REPO="${1:-.}"
shift || true
cd "$REPO"
require_git_repo
parse_time_args "$@"

echo "========== 贡献度分析 =========="
echo "仓库: $(pwd)"
echo "时间: $(time_label)"
echo "源码: C/C++/Python；构建与解释器中间产物已排除"
echo ""

echo "========== 作者去重与提交数 =========="
git log --all "${TIME_ARGS[@]}" --format='%aN <%aE>' | sort | uniq -c | sort -rn
echo ""

echo "========== 全局存活代码贡献度 =========="
git fame --incl="$SOURCE_REGEX" --excl="$IGNORED_DIR_REGEX|$IGNORED_FILE_REGEX" \
    --cost=loc,hours,months --loc=surviving -w "${TIME_ARGS[@]}"
echo ""

echo "========== 按文件类型 =========="
git fame --incl="$SOURCE_REGEX" --excl="$IGNORED_DIR_REGEX|$IGNORED_FILE_REGEX" \
    -w --bytype "${TIME_ARGS[@]}"
echo ""

echo "========== 子工程与模块贡献度 =========="
while IFS= read -r project; do
    [ "$project" = "." ] && continue
    echo "--- $project ---"
    git fame --incl="$SOURCE_REGEX" --excl="$IGNORED_DIR_REGEX|$IGNORED_FILE_REGEX" \
        -w "${TIME_ARGS[@]}" "$project" || true
    echo ""
done < <(list_project_roots)
