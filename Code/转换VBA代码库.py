# -*- coding: utf-8 -*-
"""将 D:\\Office办公\\VBE2021\\Code 目录（含子目录）的代码文件转换为 VBA代码库 CSV / XLSX。

输出格式（与「快捷短语提示器」导入兼容，5 列）：
    词库, 标题, 类别, 关键字, 内容

字段来源（按文件夹层级自动提取，不再硬编码）：
- 词库   ：【一级文件夹】名称（如 1Excel / 5个人 / 4更多 / 20260731 / 3Access / 2Word / 6WPS）。
          直接放在根目录、无一级文件夹的文件，词库记为「未分类」。
- 标题   ：文件名（去扩展名）。
- 类别   ：文件类型（类模块 .cls / 模块 .bas / 窗体 .frm / 代码 .txt）。
- 关键字 ：【二级文件夹】名称（文件所在父目录的名字）；无二级文件夹则为空。
- 内容   ：文件全文（自动清理 BOM 与控制字符）。内容位于最后一列，其后无任何列。

【内容处理原则】
- 保留原始换行（\\n），导入「快捷短语提示器」后代码按行显示，不会挤成一行。
- 「快捷短语提示器」使用标准 csv.reader 解析，逗号/引号经 csv.writer 正确引号包裹后
  可被原样还原，因此【不再把逗号/双引号替换成空格】（那样会损坏 VBA 语法）。
- 若要在 Excel 里查看完整多行代码，请用同目录生成的 VBA代码库.xlsx（原生格式不会拆行）。

【超长文件处理（按用户要求）】
- Excel 单元格上限为 32767 字符，超过此上限的代码在 Excel 中会被截断/拆行。
- 凡内容字符数 > 32767 的文件：不写入 CSV / XLSX（即“不导入”），
  改写入 未导入文件.txt 记录其相对路径、字符数、词库、关键字、文件名，便于人工处理。

【包含的文件格式（白名单）】：.txt（代码）、.bas（模块）、.cls（类模块）、.frm（窗体）
其余文件（.frx/.7z/.dll/.py/.csv 等）一律跳过。

【空文件 / 非代码内容处理】：
- 读取后内容为空（仅空白字符）的文件不写入。
- 明显非 VBA 代码的内容（编码损坏含□/�、拼音数据表全拼/拼音PY 等）过滤掉。

输出文件默认保存在本脚本所在目录（VBA代码库.csv / VBA代码库.xlsx / 未导入文件.txt），可重复运行（自动覆盖）。
导入方式：快捷短语提示器 → 设置 → 数据库 →「导入所有词库」（直接吃本 5 列格式，按第一列自动建词库）。
"""

from __future__ import annotations

import csv
import os
import re
from datetime import datetime
from pathlib import Path

# ---------- 路径配置 ----------
SOURCE_DIR = Path(r"D:\Office办公\VBE2021\Code")
OUTPUT_DIR = Path(__file__).resolve().parent
OUTPUT_CSV = OUTPUT_DIR / "VBA代码库.csv"        # 供「快捷短语提示器」导入
OUTPUT_XLSX = OUTPUT_DIR / "VBA代码库.xlsx"       # 供 Excel 查看完整多行代码
OUTPUT_UNIMPORTED = OUTPUT_DIR / "未导入文件.txt"  # 超长(超出 Excel 单元格)未导入记录

# 包含的文件格式（白名单：明确列出）
INCLUDE_EXTS = {".txt", ".bas", ".cls", ".frm"}

# 文件类型 -> 类别
TYPE_MAP = {
    ".cls": "类模块",
    ".bas": "模块",
    ".frm": "窗体",
    ".txt": "代码",
}

# Excel 单元格字符上限；超过此上限的内容在 Excel 中会截断/拆行，故跳过并记 txt
EXCEL_CELL_MAX = 32767

# 根目录文件（无一级文件夹）的默认词库名
DEFAULT_LIBRARY = "未分类"


def read_text_auto(path: Path) -> str:
    """读取文本，自动识别编码：UTF-16（BOM）→ UTF-8 → GB18030（GBK 超集，覆盖全部中文）→ 兜底。

    注意：务必尝试 gb18030 而非仅 gbk。很多 VBA 代码文件以中文 ANSI（GBK/GB2312）保存，
    仅用 gbk 可能漏解部分字符而产生大量替换符（□/�），导致被误判为“编码损坏”而丢弃真实代码。
    """
    data = path.read_bytes()
    # UTF-16 BOM 识别（Windows 记事本“Unicode”格式）
    if data[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return data.decode("utf-16")
    for encoding in ("utf-8", "gb18030"):
        try:
            return data.decode(encoding)
        except (UnicodeDecodeError, UnicodeError):
            continue
    return data.decode("utf-8", errors="replace")


def clean_content(text: str) -> str:
    """清理并规范化内容（保留换行与制表符）：

    - 去除开头 BOM
    - 统一所有换行符为 \\n（CRLF / CR / NEL / 行分隔符 / 段落分隔符 → \\n）
    - 去除其它控制字符（垂直制表/换页等不可见控制符）→ 空格；保留 \\t 与 \\n
    - 去除零宽字符 / 不换行空格
    说明：不再替换逗号/双引号——逗号与双引号由 csv.writer 自动引号包裹，
          「快捷短语提示器」用标准 csv.reader 可原样还原，避免损坏 VBA 代码。
    """
    text = text.lstrip("\ufeff")
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = text.replace("\u0085", "\n").replace("\u2028", "\n").replace("\u2029", "\n")
    text = "".join(
        ch if (ord(ch) >= 32 or ch in ("\t", "\n")) else " "
        for ch in text
    )
    text = text.replace("\u200b", "").replace("\u00a0", " ")
    return text


def detect_junk_content(text: str, title: str = "") -> tuple[bool, str]:
    """检测并过滤掉不适合入库的“非代码/不可读”内容。返回 (是否应跳过, 原因)。"""
    # 1. 编码损坏：含方块占位符（□）直接判定；Unicode 替换符（�）仅在占比偏高时判定，
    #    避免单个偶发乱码字符误杀整体正常的代码文件。
    if "\u25a1" in text:
        return True, "编码损坏（含□占位符）"
    n_fffd = text.count("\ufffd")
    if n_fffd and n_fffd / max(len(text), 1) > 0.01:
        return True, f"编码损坏（含 {n_fffd} 个替换符，占比过高）"

    # 2. 拼音数据表：内容被大量带声调拼音音节占据，不是可执行的 VBA 代码逻辑
    pinyin_tokens = re.findall(r"[a-zA-Z]+[1-5]", text)
    if len(pinyin_tokens) >= 30:
        pinyin_chars = sum(len(t) for t in pinyin_tokens)
        total_chars = max(len(text), 1)
        if pinyin_chars / total_chars > 0.30:
            return True, "拼音数据表（非 VBA 代码逻辑）"

    # 3. 标题白名单：文件名里直接带“拼音/全拼”的，也跳过（兜底）
    if "全拼" in title or "拼音" in title:
        return True, "拼音/全拼数据文件"

    return False, ""


def main() -> None:
    rows: list[list[str]] = [["词库", "标题", "类别", "关键字", "内容"]]
    unimported: list[tuple[str, int, str, str, str]] = []  # (相对路径, 字符数, 词库, 关键字, 文件名)

    total_files = 0
    skipped = 0
    empty_files = 0
    junk_files: list[tuple[str, str]] = []
    library_counter: dict[str, int] = {}

    for root, _dirs, files in os.walk(SOURCE_DIR):
        root_path = Path(root)
        for filename in sorted(files):
            file_path = root_path / filename
            if file_path == OUTPUT_CSV or file_path == OUTPUT_XLSX or file_path == OUTPUT_UNIMPORTED:
                continue
            if file_path.suffix.lower() not in INCLUDE_EXTS:
                skipped += 1
                continue
            try:
                content = clean_content(read_text_auto(file_path))
            except OSError:
                skipped += 1
                continue

            # 空内容文件（整篇仅空白字符）不写入
            if not content.strip():
                empty_files += 1
                skipped += 1
                continue

            # 过滤非代码/不可读内容
            is_junk, reason = detect_junk_content(content, file_path.stem)
            if is_junk:
                junk_files.append((file_path.relative_to(SOURCE_DIR).as_posix(), reason))
                skipped += 1
                continue

            # 按文件夹层级提取字段
            rel_parent = file_path.parent.relative_to(SOURCE_DIR)  # 文件所在目录的相对路径
            parts = rel_parent.parts  # 各级文件夹
            library = parts[0] if len(parts) >= 1 else DEFAULT_LIBRARY   # 一级文件夹 = 词库
            keyword = parts[1] if len(parts) >= 2 else ""               # 二级文件夹 = 关键字
            title = file_path.stem.strip() or filename
            category = TYPE_MAP.get(file_path.suffix.lower(), "代码")

            # 超长（超过 Excel 单元格上限）：不导入，记 txt
            if len(content) > EXCEL_CELL_MAX:
                unimported.append((
                    file_path.relative_to(SOURCE_DIR).as_posix(),
                    len(content),
                    library,
                    keyword,
                    filename,
                ))
                skipped += 1
                continue

            rows.append([library, title, category, keyword, content])
            library_counter[library] = library_counter.get(library, 0) + 1
            total_files += 1

    # 写 CSV（标准 csv.writer 自动对含逗号/换行的字段加引号，「快捷短语提示器」可原样还原）
    with OUTPUT_CSV.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerows(rows)

    # 写 XLSX（完整多行内容，原生格式不拆行；已排除超长文件）
    try:
        import openpyxl
        from openpyxl.styles import Alignment

        wb = openpyxl.Workbook()
        ws = wb.active
        ws.title = "VBA代码库"
        for r in rows:
            ws.append(r)
        # 内容列（第 5 列）不启用自动换行；保留 \n 硬换行，长行不软包裹，便于按原样查看代码
        for cell in ws.iter_cols(min_col=5, max_col=5, values_only=False):
            for c in cell:
                c.alignment = Alignment(wrap_text=False, vertical="top")
        # 各列合理宽度（内容列虽不自动换行，给足宽度便于横向查看）
        ws.column_dimensions["A"].width = 16   # 词库
        ws.column_dimensions["B"].width = 30   # 标题
        ws.column_dimensions["C"].width = 10   # 类别
        ws.column_dimensions["D"].width = 16   # 关键字
        ws.column_dimensions["E"].width = 120  # 内容
        wb.save(OUTPUT_XLSX)
        print(f"已生成: {OUTPUT_XLSX}（内容列已关闭自动换行）")
    except Exception as exc:  # pragma: no cover
        print(f"[警告] 生成 {OUTPUT_XLSX} 失败: {exc}")

    # 写 未导入文件.txt（超长未导入记录）
    if unimported:
        lines = [
            "# 未导入文件记录",
            f"# 生成时间：{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            f"# 规则：内容字符数超过 Excel 单元格上限 {EXCEL_CELL_MAX} 的文件不写入 CSV/XLSX（避免截断/拆行），在此记录以便人工处理。",
            f"# 共 {len(unimported)} 个文件",
            "# 字段：相对路径 | 字符数 | 词库(一级) | 关键字(二级) | 文件名",
            "",
        ]
        for rel, size, lib, kw, fn in sorted(unimported, key=lambda x: -x[1]):
            lines.append(f"{rel} | {size} | {lib} | {kw} | {fn}")
        OUTPUT_UNIMPORTED.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(f"已生成: {OUTPUT_UNIMPORTED}（{len(unimported)} 个超长文件）")
    else:
        # 没有超长文件时，若旧文件存在则删除，保持目录整洁
        if OUTPUT_UNIMPORTED.exists():
            OUTPUT_UNIMPORTED.unlink()
        print("无超长文件，未生成 未导入文件.txt")

    # ---------- 控制台汇总 ----------
    print(f"源目录: {SOURCE_DIR}")
    print(f"输出文件: {OUTPUT_CSV}")
    print(f"包含格式: {sorted(INCLUDE_EXTS)}")
    print(f"转换成功: {total_files} 个文件；跳过: {skipped} 个"
          f"（其中空内容 {empty_files} 个，非代码/不可读 {len(junk_files)} 个，超长未导入 {len(unimported)} 个）")
    if library_counter:
        print("[各词库(一级文件夹)条目数]:")
        for lib, cnt in sorted(library_counter.items()):
            print(f"  - {lib}: {cnt}")
    if junk_files:
        print("[已过滤的非代码/不可读文件]:")
        for rel_path, reason in junk_files:
            print(f"  - {rel_path}  →  {reason}")


if __name__ == "__main__":
    main()
