#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

REPO="${1:-.}"
shift || true
cd "$REPO"
require_git_repo
parse_time_args "$@"

echo "========== 第三方与依赖目录排查 =========="
find . -type d \( -iname 'third_party' -o -iname 'third-party' -o -iname 'vendor' -o -iname 'external' -o -iname 'deps' \) \
    -not -path '*/.git/*' -print 2>/dev/null || true
echo ""
echo "结论: 以上目录默认不纳入源码贡献度与复杂度统计；如其中包含自研代码，应按实际目录调整 common.sh 的排除规则。"
