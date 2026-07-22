#!/usr/bin/env bash

SOURCE_REGEX='\.(c|cc|cpp|cxx|h|hh|hpp|hxx|py)$'
IGNORED_DIR_REGEX='(^|/)(\.git|\.vs|\.idea|CMakeFiles|cmake-build[^/]*|build[^/]*|Debug|Release|DebugEnv|ReleaseEnv|x64|bin|obj|out|dist|__pycache__|\.pytest_cache|\.mypy_cache|\.ruff_cache|\.tox|\.nox|\.venv|venv|env|site-packages|node_modules|\.eggs|[^/]+\.egg-info|third_party|third-party|vendor|external|deps)(/|$)'
IGNORED_FILE_REGEX='(\.obj|\.o|\.a|\.lib|\.dll|\.so|\.dylib|\.exe|\.pdb|\.ilk|\.pyc|\.pyo|\.whl|\.class|\.jar)$|(^|/)(moc_|ui_)'
TIME_ARGS=()

die() {
    echo "错误: $*" >&2
    exit 2
}

require_git_repo() {
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "不是 Git 仓库: $(pwd)"
}

parse_time_args() {
    TIME_ARGS=()
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --since)
                [ -n "${2:-}" ] || die "--since 需要明确日期或时间表达式"
                TIME_ARGS+=("--since=$2")
                shift 2
                ;;
            --until)
                [ -n "${2:-}" ] || die "--until 需要明确日期或时间表达式"
                TIME_ARGS+=("--until=$2")
                shift 2
                ;;
            --since=*|--until=*)
                TIME_ARGS+=("$1")
                shift
                ;;
            *)
                die "不支持的参数: $1"
                ;;
        esac
    done
}

time_label() {
    if [ "${#TIME_ARGS[@]}" -eq 0 ]; then
        echo "全部历史"
    else
        printf '%s ' "${TIME_ARGS[@]}"
    fi
}

is_ignored_path() {
    printf '%s\n' "$1" | grep -Eiq "$IGNORED_DIR_REGEX|$IGNORED_FILE_REGEX"
}

filtered_tracked_source_files() {
    git ls-files -z | tr '\0' '\n' | \
        grep -Ei "$SOURCE_REGEX" | \
        grep -Eiv "$IGNORED_DIR_REGEX|$IGNORED_FILE_REGEX" || true
}

list_project_roots() {
    {
        printf '.\n'
        find . -type f \( -name 'CMakeLists.txt' -o -name 'pyproject.toml' -o -name 'setup.py' \) -print0 2>/dev/null | \
            while IFS= read -r -d '' marker; do
                root=$(dirname "$marker")
                if ! is_ignored_path "$root"; then
                    printf '%s\n' "${root#./}"
                fi
            done
        git submodule foreach --quiet 'printf "%s\n" "$sm_path"' 2>/dev/null || true
        find . -type d -name .git -print0 2>/dev/null | \
            while IFS= read -r -d '' git_dir; do
                root=$(dirname "$git_dir")
                if [ "$root" != "." ] && ! is_ignored_path "$root"; then
                    printf '%s\n' "${root#./}"
                fi
            done
    } | sed '/^$/d' | sort -u
}
