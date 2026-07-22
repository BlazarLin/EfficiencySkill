#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

REPO="${1:-.}"
shift || true
cd "$REPO"
require_git_repo
parse_time_args "$@"

echo "========== 分支活跃度 =========="
echo "仓库: $(pwd)"
echo "时间: $(time_label)"
echo ""

echo "========== 分支列表 =========="
git for-each-ref --sort=-committerdate --format='%(refname:short) | %(committerdate:short) | %(authorname)' refs/heads refs/remotes
echo ""

echo "========== 时间范围内的分支提交数 =========="
while IFS= read -r branch; do
    [ -z "$branch" ] && continue
    count=$(git rev-list --count "${TIME_ARGS[@]}" "$branch")
    printf '%8s  %s\n' "$count" "$branch"
done < <(git for-each-ref --format='%(refname:short)' refs/heads | sort -u)
echo ""

echo "========== 最近提交 =========="
git log --all "${TIME_ARGS[@]}" --date=short --format='%ad | %an | %h | %s' -n 30
