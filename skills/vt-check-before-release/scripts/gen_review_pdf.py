#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Skill resource: vt-check-before-release/scripts
"""
创建时间: 2026-07-23
功能: 发布前审查报告 Markdown -> HTML -> PDF 全流程生成（vt-check-before-release 技能资源）
目的: 固化 PDF 生成逻辑，避免每次运行技能时手写临时脚本浪费 token
用法:
    python gen_review_pdf.py <md_path> [pdf_path]
    pdf_path 省略时自动取 md_path 同名 .pdf
依赖: Python3 + markdown-it-py + pypdf + Chrome 或 Edge
退出码: 0 成功; 非 0 失败
"""
import os
import sys
import shutil
import subprocess
import importlib


PYTHON_DEPENDENCIES = (
    ("markdown_it", "markdown-it-py"),
    ("pypdf", "pypdf"),
)


# ---------- CSS（含花括号，用普通字符串，不可用 f-string 拼接）----------
CSS = """
@page { size: A4; margin: 14mm 14mm 16mm 14mm; }
* { box-sizing: border-box; }
body {
    font-family: "Microsoft YaHei", "微软雅黑", "Segoe UI", Arial, sans-serif;
    font-size: 10.5pt;
    line-height: 1.6;
    color: #222;
    margin: 0;
    padding: 0;
}
h1 { font-size: 18pt; color: #1a3a6b; border-bottom: 3px solid #1a3a6b; padding-bottom: 6px; margin-top: 0; }
h2 { font-size: 14pt; color: #1a3a6b; border-bottom: 1px solid #b8c4d8; padding-bottom: 4px; margin-top: 22px; page-break-after: avoid; }
h3 { font-size: 12pt; color: #2c5282; margin-top: 18px; page-break-after: avoid; }
h4 { font-size: 11pt; color: #3a4a6b; margin-top: 14px; page-break-after: avoid; }
p { margin: 6px 0; }
strong { color: #1a3a6b; }
code {
    font-family: "Consolas", "Courier New", monospace;
    background: #f0f2f5;
    padding: 1px 5px;
    border-radius: 3px;
    font-size: 9.5pt;
    color: #c0392b;
}
pre { background: #f6f8fa; padding: 10px 12px; border-radius: 4px; overflow-x: auto; page-break-inside: avoid; }
pre code { background: none; color: #24292e; padding: 0; }
blockquote {
    border-left: 4px solid #4a90d9;
    background: #eef5fc;
    margin: 10px 0;
    padding: 8px 14px;
    color: #2c3e50;
    border-radius: 0 4px 4px 0;
}
blockquote p { margin: 4px 0; }
table {
    border-collapse: collapse;
    width: 100%;
    margin: 10px 0;
    font-size: 10pt;
    page-break-inside: auto;
}
thead { display: table-header-group; }
tr { page-break-inside: avoid; page-break-after: auto; }
th {
    background: #2c5282;
    color: #fff;
    font-weight: 600;
    padding: 7px 10px;
    text-align: left;
    border: 1px solid #2c5282;
}
td {
    padding: 6px 10px;
    border: 1px solid #d0d7e2;
    vertical-align: top;
}
tbody tr:nth-child(even) { background: #f4f7fb; }
tbody tr:nth-child(odd) { background: #fff; }
ul, ol { margin: 6px 0; padding-left: 24px; }
li { margin: 3px 0; }
hr { border: none; border-top: 1px solid #ccc; margin: 18px 0; }
a { color: #2c5282; text-decoration: none; }
"""


def ensure_python_dependencies():
    """自动安装并验证 PDF 生成所需的 Python 包。"""
    for module_name, package_name in PYTHON_DEPENDENCIES:
        try:
            importlib.import_module(module_name)
            continue
        except ImportError:
            print("[依赖] 安装缺失包:", package_name)

        result = subprocess.run(
            [
                sys.executable,
                "-m",
                "pip",
                "install",
                "--disable-pip-version-check",
                package_name,
            ]
        )
        if result.returncode != 0:
            print("ERROR: 依赖安装失败:", package_name)
            return False

        importlib.invalidate_caches()
        try:
            importlib.import_module(module_name)
        except ImportError:
            print("ERROR: 安装后仍无法导入:", module_name)
            return False
    return True


def cleanup_file(path):
    """删除脚本生成的临时文件。"""
    try:
        if os.path.exists(path):
            os.remove(path)
    except OSError:
        pass


def preserve_markdown_notice(md_path):
    """明确告知调用方 PDF 失败时保留了 Markdown。"""
    print("PDF 生成失败，Markdown 已保留:", md_path)


def find_chrome():
    """查找 Chrome 或 Edge 可执行文件"""
    candidates = [
        r"C:\Program Files\Google\Chrome\Application\chrome.exe",
        r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
        r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
    ]
    for c in candidates:
        if os.path.exists(c):
            return c
    return None


def md_to_html(md_path, html_path):
    """Markdown 转 HTML（GFM default preset + table）"""
    import markdown_it

    with open(md_path, encoding="utf-8") as f:
        md_text = f.read()

    # 注意：markdown-it-py 3.0 不支持 preset= 关键字参数，用位置参数 configName
    # "default" preset 已含 table 规则，enable 显式保险
    md = markdown_it.MarkdownIt("default", options_update={"html": True})
    md.enable(["table"])
    body = md.render(md_text)

    html = (
        "<!DOCTYPE html><html><head><meta charset='utf-8'><style>"
        + CSS
        + "</style></head><body>"
        + body
        + "</body></html>"
    )

    with open(html_path, "w", encoding="utf-8") as f:
        f.write(html)
    return len(html)


def chrome_to_pdf(chrome_path, html_path, pdf_path):
    """Chrome headless 转 PDF"""
    file_url = "file:///" + os.path.abspath(html_path).replace("\\", "/")
    cmd = [
        chrome_path,
        "--headless=new",
        "--disable-gpu",
        "--no-pdf-header-footer",
        "--print-to-pdf=" + os.path.abspath(pdf_path),
        file_url,
    ]
    # capture_output 避免 Chrome 日志污染
    subprocess.run(cmd, capture_output=True, timeout=120)
    return os.path.exists(pdf_path) and os.path.getsize(pdf_path) > 0


def verify_pdf(pdf_path):
    """用 pypdf 验证页数和中文渲染"""
    try:
        import pypdf

        reader = pypdf.PdfReader(pdf_path)
        pages = len(reader.pages)
        txt = reader.pages[0].extract_text() or ""
        cn_ok = any(k in txt for k in ("审查", "发布", "代码"))
        return pages, cn_ok
    except Exception as e:
        return -1, False


def main():
    if len(sys.argv) < 2:
        print("用法: python gen_review_pdf.py <md_path> [pdf_path]")
        print("  pdf_path 省略时自动取 md_path 同名 .pdf")
        sys.exit(2)

    md_path = os.path.abspath(sys.argv[1])
    if not os.path.exists(md_path):
        print("ERROR: md 文件不存在:", md_path)
        sys.exit(1)

    if len(sys.argv) >= 3:
        pdf_path = os.path.abspath(sys.argv[2])
    else:
        pdf_path = os.path.splitext(md_path)[0] + ".pdf"

    work_dir = os.path.dirname(md_path)
    html_path = os.path.join(work_dir, "_review_tmp.html")
    new_pdf = os.path.join(work_dir, "_review_new.pdf")

    if not ensure_python_dependencies():
        preserve_markdown_notice(md_path)
        sys.exit(1)

    # 1. Markdown -> HTML
    try:
        html_size = md_to_html(md_path, html_path)
        print("[1/4] HTML 生成:", html_path, "(", html_size, "bytes )")
    except Exception as e:
        print("ERROR: HTML 生成失败:", e)
        cleanup_file(html_path)
        preserve_markdown_notice(md_path)
        sys.exit(1)

    # 2. Chrome -> PDF
    chrome = find_chrome()
    if not chrome:
        print("ERROR: 未找到 Chrome 或 Edge，请安装后重试")
        cleanup_file(html_path)
        preserve_markdown_notice(md_path)
        sys.exit(1)
    print("[2/4] 使用浏览器:", chrome)
    if not chrome_to_pdf(chrome, html_path, new_pdf):
        print("ERROR: PDF 生成失败（Chrome headless 未产出文件）")
        cleanup_file(new_pdf)
        cleanup_file(html_path)
        preserve_markdown_notice(md_path)
        sys.exit(1)
    print("       临时 PDF:", new_pdf, "(", os.path.getsize(new_pdf), "bytes )")

    # 3. 验证
    pages, cn_ok = verify_pdf(new_pdf)
    if pages < 1:
        print("ERROR: pypdf 验证失败，拒绝替换正式 PDF")
        cleanup_file(new_pdf)
        cleanup_file(html_path)
        preserve_markdown_notice(md_path)
        sys.exit(1)

    print("[3/4] 验证: 页数 =", pages, "| 中文渲染 =", "OK" if cn_ok else "异常")
    if not cn_ok:
        print("       WARNING: 首页未检出中文，可能渲染异常")

    # 4. 替换正式 PDF（处理占用）
    print("[4/4] 替换正式 PDF:", pdf_path)
    try:
        if os.path.exists(pdf_path):
            os.remove(pdf_path)
        shutil.move(new_pdf, pdf_path)
        print("       替换成功")
    except PermissionError:
        print("       WARNING: 正式 PDF 被占用（阅读器打开？），临时版保留:", new_pdf)
        print("       关闭阅读器后手动改名，或重跑本脚本")
        cleanup_file(html_path)
        preserve_markdown_notice(md_path)
        sys.exit(1)
    except Exception as e:
        print("       WARNING: 替换失败:", e, "| 临时版保留:", new_pdf)
        cleanup_file(html_path)
        preserve_markdown_notice(md_path)
        sys.exit(1)

    # 5. 成功后清理临时 HTML 与 Markdown
    cleanup_file(html_path)
    cleanup_file(md_path)

    print("完成。")
    sys.exit(0)


if __name__ == "__main__":
    main()
