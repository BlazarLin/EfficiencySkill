#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

REPO="${1:-.}"
shift || true
cd "$REPO"
REPO="$(pwd)"
require_git_repo
parse_time_args "$@"

echo "========== 工程活跃度分析 =========="
echo "父工程: $REPO"
echo "时间范围: $(time_label)"
echo ""

echo "========== 发现的子工程 =========="
list_project_roots
echo ""

bash "$SCRIPT_DIR/contribution.sh" "$REPO" "${TIME_ARGS[@]}"
echo ""
bash "$SCRIPT_DIR/branches.sh" "$REPO" "${TIME_ARGS[@]}"
echo ""
bash "$SCRIPT_DIR/audit-thirdparty.sh" "$REPO"
echo ""
bash "$SCRIPT_DIR/audit-artifacts.sh" "$REPO"
echo ""

while IFS= read -r project; do
    [ "$project" = "." ] && continue
    project_top=$(git -C "$REPO/$project" rev-parse --show-toplevel 2>/dev/null || true)
    if [ -n "$project_top" ] && [ "$project_top" != "$REPO" ]; then
        echo "========== 独立子工程: $project =========="
        bash "$SCRIPT_DIR/contribution.sh" "$REPO/$project" "${TIME_ARGS[@]}"
        bash "$SCRIPT_DIR/branches.sh" "$REPO/$project" "${TIME_ARGS[@]}"
    fi
done < <(list_project_roots)
