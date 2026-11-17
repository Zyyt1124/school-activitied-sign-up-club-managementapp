# -*- coding: utf-8 -*-
"""生成中期答辩 PPT（第 1–6 周进展汇报），语言面向大二学生。

结构：
  一、做成了什么（前 6 周计划完成情况、手机端 / 服务器端 / 数据库、完整流程、测试）
  二、踩过的坑（开发工具、数据库、前后端配合）
  三、后面怎么干（第 7–12 周，具体到周）

设计沿用开题 PPT：白底、深色标题、蓝色强调条、橙色关键词、微软雅黑。
尽量减少术语：用「手机端 / 服务器端」「同时报名」「防重复编号」
「一组操作一起成功或失败」等直白说法。

用法：
  py -3.13 scripts/pptx/build_midterm_ppt.py 校园活动与社团管理_中期答辩.pptx

注意：测试数字是「按第 6 周计划完成」假设的示例值，
答辩前请用真实结果替换 METRICS 中的常量。
"""
import sys
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.enum.shapes import MSO_SHAPE
from pptx.oxml.ns import qn
from lxml import etree

FONT = "微软雅黑"
MONO = "Consolas"

INK = "1F242B"
INK2 = "3C424A"
MUTED = "8B939D"
BLUE = "2E6FB8"
ORANGE = "C16B2E"
BG = "F5F7F9"
LINE = "DEE2E7"
BORDER = "C9CED6"
WHITE = "FFFFFF"
GREEN = "2F7D5A"
ORANGE_SOFT = "FBF1E9"
BLUE_SOFT = "EDF3FA"

# ---- 示例指标：答辩前替换为真实测试 / 修改记录 ----
METRICS = {
    "concurrency": 50,
    "seats": 10,
    "success": 10,
    "oversell": 0,
    "p95_ms": 186,
    "bugs_found": 11,
    "bugs_fixed": 9,
    "bugs_left": 2,
}

TOTAL_SLIDES = 15


def rgb(hex_value):
    return RGBColor.from_string(hex_value)


def style_run(run, size, bold=False, color=INK2, font=FONT, ea=None):
    run.font.name = font
    run.font.size = Pt(size)
    run.font.bold = bold
    run.font.color.rgb = rgb(color)
    rPr = run._r.get_or_add_rPr()
    for tag in ("a:ea", "a:cs", "a:sym"):
        el = rPr.find(qn(tag))
        if el is None:
            el = etree.SubElement(rPr, qn(tag))
        el.set("typeface", ea or font)


def _fill_para(para, spec):
    para.alignment = spec.get("align", PP_ALIGN.LEFT)
    if "space_after" in spec:
        para.space_after = Pt(spec["space_after"])
    if "space_before" in spec:
        para.space_before = Pt(spec["space_before"])
    if "line" in spec:
        para.line_spacing = spec["line"]
    for rd in spec.get("runs", []):
        run = para.add_run()
        run.text = rd["t"]
        style_run(
            run,
            rd.get("size", 12),
            rd.get("bold", False),
            rd.get("color", INK2),
            rd.get("font", FONT),
            rd.get("ea"),
        )


def add_text(slide, x, y, w, h, paras, anchor=MSO_ANCHOR.TOP, margins=(0, 0, 0, 0)):
    box = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
    tf = box.text_frame
    tf.word_wrap = True
    tf.vertical_anchor = anchor
    tf.margin_left = Inches(margins[0])
    tf.margin_right = Inches(margins[1])
    tf.margin_top = Inches(margins[2])
    tf.margin_bottom = Inches(margins[3])
    for i, spec in enumerate(paras):
        para = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        _fill_para(para, spec)
    return box


def add_rect(slide, x, y, w, h, fill, line=None, rounded=False, radius=None):
    shape_type = MSO_SHAPE.ROUNDED_RECTANGLE if rounded else MSO_SHAPE.RECTANGLE
    shp = slide.shapes.add_shape(shape_type, Inches(x), Inches(y), Inches(w), Inches(h))
    shp.fill.solid()
    shp.fill.fore_color.rgb = rgb(fill)
    if line:
        shp.line.color.rgb = rgb(line)
        shp.line.width = Pt(0.75)
    else:
        shp.line.fill.background()
    shp.shadow.inherit = False
    if rounded and radius is not None and len(shp.adjustments):
        shp.adjustments[0] = radius
    return shp


def add_circle(slide, x, y, d, fill, text=None, color=WHITE, size=12):
    shp = slide.shapes.add_shape(MSO_SHAPE.OVAL, Inches(x), Inches(y), Inches(d), Inches(d))
    shp.fill.solid()
    shp.fill.fore_color.rgb = rgb(fill)
    shp.line.fill.background()
    shp.shadow.inherit = False
    if text is not None:
        tf = shp.text_frame
        tf.word_wrap = False
        tf.margin_left = 0
        tf.margin_right = 0
        tf.margin_top = 0
        tf.margin_bottom = 0
        p = tf.paragraphs[0]
        p.alignment = PP_ALIGN.CENTER
        run = p.add_run()
        run.text = text
        style_run(run, size, True, color)
    return shp


def add_arrow(slide, x, y, w=0.22, h=0.28, color=BLUE):
    shp = slide.shapes.add_shape(MSO_SHAPE.RIGHT_ARROW, Inches(x), Inches(y), Inches(w), Inches(h))
    shp.fill.solid()
    shp.fill.fore_color.rgb = rgb(color)
    shp.line.fill.background()
    shp.shadow.inherit = False
    return shp


def add_chip(slide, x, y, w, h, text, fill=BLUE_SOFT, color=BLUE, size=8.5, bold=False):
    add_rect(slide, x, y, w, h, fill, rounded=True, radius=0.45)
    add_text(slide, x, y, w, h, [{"align": PP_ALIGN.CENTER, "runs": [
        {"t": text, "size": size, "bold": bold, "color": color},
    ]}], anchor=MSO_ANCHOR.MIDDLE)


def content_slide(prs, section, title, subtitle=None):
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    for ph in list(slide.placeholders):
        ph._element.getparent().remove(ph._element)
    slide.background.fill.solid()
    slide.background.fill.fore_color.rgb = rgb(WHITE)
    add_text(slide, 0.72, 0.50, 11.89, 0.28,
             [{"runs": [{"t": section, "size": 11, "color": MUTED}]}])
    add_text(slide, 0.72, 0.82, 11.89, 0.62,
             [{"runs": [{"t": title, "size": 26, "bold": True, "color": INK}]}])
    add_rect(slide, 0.72, 1.40, 0.85, 0.05, BLUE)
    if subtitle:
        add_text(slide, 0.72, 1.72, 11.89, 0.34,
                 [{"runs": [{"t": subtitle, "size": 15, "bold": True, "color": ORANGE}]}])
    return slide


def add_footer(slide, page):
    add_text(slide, 9.35, 7.06, 3.25, 0.26, [{"align": PP_ALIGN.RIGHT, "runs": [
        {"t": "社团管理平台 中期答辩　", "size": 9, "color": MUTED},
        {"t": str(page), "size": 10, "bold": True, "color": MUTED},
    ]}])


def add_takeaway(slide, text):
    add_rect(slide, 0.72, 6.16, 0.90, 0.05, ORANGE)
    add_text(slide, 0.72, 6.38, 11.89, 0.52, [{"runs": [
        {"t": "一句话　", "size": 11.5, "bold": True, "color": ORANGE},
        {"t": text, "size": 15, "bold": True, "color": INK},
    ]}])


def add_panel(slide, x, y, w, h, fill=BG):
    add_rect(slide, x, y, w, h, fill)


def add_panel_heading(slide, x, y, w, text, color=BLUE, size=14.5):
    add_text(slide, x, y, w, 0.30, [{"runs": [
        {"t": text, "size": size, "bold": True, "color": color},
    ]}])


def _border_el(tag, color, width):
    ln = etree.Element(qn(tag))
    ln.set("w", str(int(width * 12700)))
    ln.set("cap", "flat")
    ln.set("cmpd", "sng")
    ln.set("algn", "ctr")
    solid = etree.SubElement(ln, qn("a:solidFill"))
    clr = etree.SubElement(solid, qn("a:srgbClr"))
    clr.set("val", color)
    dash = etree.SubElement(ln, qn("a:prstDash"))
    dash.set("val", "solid")
    etree.SubElement(ln, qn("a:round"))
    head = etree.SubElement(ln, qn("a:headEnd"))
    head.set("type", "none")
    head.set("w", "med")
    head.set("len", "med")
    tail = etree.SubElement(ln, qn("a:tailEnd"))
    tail.set("type", "none")
    tail.set("w", "med")
    tail.set("len", "med")
    return ln


def set_cell_border(cell, color=BORDER, width=0.75):
    tcPr = cell._tc.get_or_add_tcPr()
    for tag in ("a:lnL", "a:lnR", "a:lnT", "a:lnB"):
        for el in tcPr.findall(qn(tag)):
            tcPr.remove(el)
    for i, tag in enumerate(("a:lnL", "a:lnR", "a:lnT", "a:lnB")):
        tcPr.insert(i, _border_el(tag, color, width))


def add_table(slide, x, y, col_widths, rows, row_height=0.55, body_size=9.0,
              header_size=9.8, center_cols=(0,), header_fill=LINE,
              bold_first_col=False, status_col=None, header_height=None):
    nrows = len(rows)
    ncols = len(col_widths)
    width = sum(col_widths)
    shape = slide.shapes.add_table(
        nrows, ncols, Inches(x), Inches(y), Inches(width), Inches(row_height * nrows))
    table = shape.table
    tbl = table._tbl
    for el in tbl.tblPr.findall(qn("a:tableStyleId")):
        tbl.tblPr.remove(el)
    table.first_row = False
    table.horz_banding = False
    table.vert_banding = False
    for i, cw in enumerate(col_widths):
        table.columns[i].width = Inches(cw)
    for ri, row in enumerate(rows):
        table.rows[ri].height = Inches(
            (header_height if (ri == 0 and header_height) else row_height))
        for ci, value in enumerate(row):
            cell = table.cell(ri, ci)
            set_cell_border(cell)
            cell.margin_left = Inches(0.08)
            cell.margin_right = Inches(0.07)
            cell.margin_top = Inches(0.03)
            cell.margin_bottom = Inches(0.03)
            cell.vertical_anchor = MSO_ANCHOR.MIDDLE
            cell.fill.solid()
            if ri == 0:
                cell.fill.fore_color.rgb = rgb(header_fill)
            else:
                cell.fill.fore_color.rgb = rgb(WHITE if ri % 2 == 1 else "FBFCFD")
            tf = cell.text_frame
            tf.word_wrap = True
            p = tf.paragraphs[0]
            for r in list(p.runs):
                r._r.getparent().remove(r._r)
            run = p.add_run()
            run.text = str(value)
            color = INK if ri == 0 else INK2
            bold = ri == 0 or (bold_first_col and ci == 0)
            if ri > 0 and status_col is not None and ci == status_col:
                color = ORANGE if ("2" in str(value) or "进行" in str(value)
                                   or "持续" in str(value) or "达到" in str(value)) else BLUE
                bold = True
            style_run(run, header_size if ri == 0 else body_size, bold, color)
            if ci in center_cols:
                p.alignment = PP_ALIGN.CENTER
            else:
                p.alignment = PP_ALIGN.LEFT
    return shape


def add_bullets(slide, x, y, w, h, items, size=11.5, gap=5, line=1.12, color=INK2):
    paras = []
    for item in items:
        if isinstance(item, tuple):
            head, body = item
            paras.append({"space_after": gap, "line": line, "runs": [
                {"t": "·　", "size": size, "bold": True, "color": BLUE},
                {"t": head, "size": size, "bold": True, "color": INK},
                {"t": body, "size": size, "color": color},
            ]})
        else:
            paras.append({"space_after": gap, "line": line, "runs": [
                {"t": "·　", "size": size, "bold": True, "color": BLUE},
                {"t": item, "size": size, "color": color},
            ]})
    return add_text(slide, x, y, w, h, paras)


def add_note(slide, x, y, w, h, text, size=9, color=MUTED, align=PP_ALIGN.LEFT):
    add_text(slide, x, y, w, h, [{"align": align, "runs": [
        {"t": text, "size": size, "color": color},
    ]}])


def add_speaker_notes(slide, text):
    slide.notes_slide.notes_text_frame.text = text


# ---------------------------------------------------------------------------
# 页面
# ---------------------------------------------------------------------------

def slide_cover(prs):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    for ph in list(s.placeholders):
        ph._element.getparent().remove(ph._element)
    s.background.fill.solid()
    s.background.fill.fore_color.rgb = rgb(WHITE)

    add_text(s, 9.30, 0.62, 3.25, 0.26, [{"align": PP_ALIGN.RIGHT, "runs": [
        {"t": "进度　", "size": 10, "color": MUTED},
        {"t": "6 / 12 周", "size": 11.5, "bold": True, "color": BLUE},
    ]}])
    for i in range(12):
        add_rect(s, 9.30 + i * 0.265, 0.96, 0.22, 0.09, BLUE if i < 6 else LINE)

    add_rect(s, 1.15, 1.18, 3.30, 0.38, ORANGE_SOFT, rounded=True, radius=0.5)
    add_text(s, 1.15, 1.18, 3.30, 0.38, [{"align": PP_ALIGN.CENTER, "runs": [
        {"t": "中期答辩 · 前 6 周我们做了什么", "size": 11.5, "bold": True, "color": ORANGE},
    ]}], anchor=MSO_ANCHOR.MIDDLE)

    add_text(s, 1.15, 1.72, 11.20, 0.85, [{"runs": [
        {"t": "校园活动与社团管理平台", "size": 40, "bold": True, "color": INK},
    ]}])
    add_text(s, 1.15, 2.55, 11.20, 0.45, [{"runs": [
        {"t": "基于仓颉 + ArkTS 的鸿蒙原生应用", "size": 22, "bold": True, "color": INK2},
    ]}])
    add_text(s, 1.15, 3.00, 11.20, 0.34, [{"runs": [
        {"t": "学生、社团负责人、管理员都能用的校园平台", "size": 14, "color": MUTED},
    ]}])

    add_rect(s, 1.15, 3.62, 11.03, 1.22, INK, rounded=True, radius=0.04)
    add_text(s, 1.45, 3.78, 10.45, 0.92, [
        {"space_after": 4, "runs": [
            {"t": "前 6 周，我们把「发布 → 报名 → 名单」真正跑通了。", "size": 17, "bold": True, "color": WHITE},
        ]},
        {"runs": [
            {"t": "下一步：补上消息、统计和管理员功能，第 12 周提交上架。", "size": 17, "bold": True, "color": "FFC17A"},
        ]},
    ], anchor=MSO_ANCHOR.MIDDLE)

    add_text(s, 1.15, 5.32, 11.20, 0.68, [
        {"space_after": 3, "runs": [
            {"t": "组员　", "size": 12.5, "color": MUTED},
            {"t": "林家俊　严一凡　朱一言", "size": 12.5, "bold": True, "color": INK2},
        ]},
        {"runs": [
            {"t": "汇报日期　", "size": 12.5, "color": MUTED},
            {"t": "2026 年 11 月", "size": 12.5, "bold": True, "color": INK2},
        ]},
    ])
    add_speaker_notes(s, "各位老师好，我们汇报第 1 到 6 周的中期进展。今天只讲三件事："
                         "已经做成了什么、过程中遇到了哪些问题、接下来 6 周怎么安排。"
                         "先说结论：发布、报名、看名单这条完整流程已经能走通，"
                         "大家最担心的「同时报名会不会超名额」也已经解决。")


def slide_agenda(prs):
    s = content_slide(prs, "今天讲什么", "今天只回答三个问题",
                      "做出了什么、踩了哪些坑、后面怎么干。")
    items = [
        ("01", "已经做出来的东西",
         "前 6 周原计划做什么、实际做成了什么；手机端、服务器端、数据库分别能拿出什么", BLUE),
        ("02", "踩过的坑",
         "开发工具、数据库、前后端配合上遇到了什么问题，我们是怎么绕过去的", ORANGE),
        ("03", "后面 6 周怎么干",
         "第 7–12 周每周做什么、周末能拿出什么、什么时候停止加功能", INK),
    ]
    for i, (num, title, desc, color) in enumerate(items):
        y = 2.10 + i * 1.28
        add_panel(s, 0.72, y, 11.89, 1.08)
        add_text(s, 1.00, y + 0.18, 0.75, 0.55, [{"runs": [
            {"t": num, "size": 26, "bold": True, "color": color},
        ]}])
        add_text(s, 1.85, y + 0.16, 3.15, 0.38, [{"runs": [
            {"t": title, "size": 17, "bold": True, "color": INK},
        ]}])
        add_text(s, 4.95, y + 0.14, 7.35, 0.72, [{"line": 1.15, "runs": [
            {"t": desc, "size": 12, "color": INK2},
        ]}], anchor=MSO_ANCHOR.MIDDLE)
    add_takeaway(s, "前 6 周不是「写完了」，而是「能演示、能测试、还能接着加功能」。")
    add_speaker_notes(s, "汇报按这三块走。第一部分给出能现场演示的成果和测试数字；"
                         "第二部分不回避问题，重点讲怎么解决；第三部分逐周排到第 12 周。")


def slide_progress(prs):
    s = content_slide(prs, "一、做成了什么　1 / 7", "前 6 周：原计划的事都做完了",
                      "从「三个人都能跑起来」到「发布、报名、看名单能演示」，三个阶段的目标都达到了。")
    rows = [
        ["周", "原计划", "实际做出来的", "情况"],
        ["1", "原型、选什么技术、数据库表；三个人本机都能跑",
         "开题 PPT；整体结构、数据库、接口文档；手机端和服务器端都能编译通过", "做完了"],
        ["2", "把接口定下来；手机端能登录、能拿活动列表",
         "30 个后台接口、错误提示、三种角色的权限都定下来；手机端能登录并显示活动", "做完了"],
        ["3", "登录、浏览活动；社团创建和审核",
         "登录 + 活动列表 / 详情；三种角色看到的入口不同；社团创建→审核→展示走通", "做完了"],
        ["4", "社团和入社；活动发布和状态规则",
         "活动草稿 / 发布 / 状态变化规则；没有权限的操作会被拒绝", "做完了"],
        ["5", "发布 → 报名 → 取消能演示",
         "报名前的检查、防重复提交、名额扣减；取消后归还名额；手机端按钮和名额同步", "做完了"],
        ["6", "报名名单、同时报名测试、完整流程",
         f"{METRICS['concurrency']} 人同时抢 {METRICS['seats']} 个名额通过；名单、筛选、导出入口可用", "达到目标"],
    ]
    add_table(s, 0.72, 2.08, [0.60, 3.05, 6.55, 1.69], rows,
              row_height=0.545, body_size=9.2, header_size=9.8,
              center_cols=(0, 3), status_col=3, header_height=0.50)
    add_takeaway(s, "三个人都能开发、接口定下来、完整流程能演示，前 6 周的目标都达到了。")
    add_speaker_notes(s, "这张表按周对照开题时的承诺。第 1 周到第 6 周没有延期，"
                         "第 2 周把接口定下来、第 6 周把完整流程跑通，两个关键点都按计划完成。"
                         "第 6 周的测试结果下一页展开。")


def slide_overview(prs):
    s = content_slide(prs, "一、做成了什么　2 / 7", "三条线都有拿得出手的东西",
                      "不是「写了很多代码」，而是手机端、服务器端、数据库都能拿出来单独看。")
    stats = [
        ("30", "个后台接口", "登录 / 活动 / 报名 / 社团 / 消息 / 管理员", BLUE),
        ("6", "张数据表", "用户 / 社团 / 活动 / 报名 / 消息 / 操作记录", BLUE),
        ("4", "个手机页面", "登录 / 列表 / 详情 / 我的，另有 3 个通用组件", ORANGE),
        ("0", "超报名额", f"{METRICS['concurrency']} 人同时抢 {METRICS['seats']} 个名额，成功刚好 {METRICS['success']} 人", ORANGE),
    ]
    for i, (value, label, note, color) in enumerate(stats):
        x = 0.72 + i * 3.01
        add_panel(s, x, 2.05, 2.87, 1.28)
        add_text(s, x + 0.18, 2.13, 0.95, 0.52, [{"runs": [
            {"t": value, "size": 30, "bold": True, "color": color},
        ]}])
        add_text(s, x + 1.00, 2.20, 1.70, 0.30, [{"runs": [
            {"t": label, "size": 12, "bold": True, "color": INK},
        ]}])
        add_text(s, x + 0.18, 2.68, 2.52, 0.50, [{"line": 1.08, "runs": [
            {"t": note, "size": 8.8, "color": MUTED},
        ]}])

    tracks = [
        ("手机端 A", "登录、活动列表、活动详情、报名 / 取消、我的报名、名单；加载中、没有数据、出错都有提示；所有网络请求只从一个地方发出。", BLUE),
        ("服务器端 B", "接请求、做功能、定规则、读写数据库四块；活动状态、权限、防重复、名额扣减都在服务器端完成。", BLUE),
        ("数据库 C", "6 张表，关键字段有检查和唯一限制；名额用一条语句同时判断和扣减；内存版已经换成真正的数据库版本。", ORANGE),
    ]
    for i, (label, body, color) in enumerate(tracks):
        y = 3.60 + i * 0.72
        add_rect(s, 0.72, y, 11.89, 0.62, BG)
        add_text(s, 0.92, y, 1.35, 0.62, [{"runs": [
            {"t": label, "size": 12.5, "bold": True, "color": color},
        ]}], anchor=MSO_ANCHOR.MIDDLE)
        add_text(s, 2.35, y, 10.05, 0.62, [{"runs": [
            {"t": body, "size": 10.2, "color": INK2},
        ]}], anchor=MSO_ANCHOR.MIDDLE)
    add_takeaway(s, "三条线用的是同一份接口格式，一起调试时不用猜对方会返回什么。")
    add_speaker_notes(s, "四个数字先给总体印象：30 个后台接口、6 张表、4 个手机页面、0 超报名额。"
                         "下面三条线分别对应 A、B、C 三位同学，每条线都有可以单独检查的成果。")


def add_phone(slide, x, y, w, h, title, subtitle, cards, button=None, footer=None):
    add_rect(slide, x, y, w, h, WHITE, BORDER, rounded=True, radius=0.07)
    add_rect(slide, x + 0.09, y + 0.16, w - 0.18, h - 0.32, BG, rounded=True, radius=0.05)
    add_rect(slide, x + w / 2 - 0.24, y + 0.07, 0.48, 0.055, LINE, rounded=True, radius=0.5)
    add_text(slide, x + 0.20, y + 0.26, w - 0.40, 0.26, [{"runs": [
        {"t": title, "size": 11, "bold": True, "color": INK},
    ]}])
    if subtitle:
        add_text(slide, x + 0.20, y + 0.52, w - 0.40, 0.22, [{"runs": [
            {"t": subtitle, "size": 7.8, "color": MUTED},
        ]}])
    cy = y + 0.82
    for card in cards:
        ctype = card[0]
        if ctype == "search":
            add_rect(slide, x + 0.18, cy, w - 0.36, 0.28, WHITE, LINE, rounded=True, radius=0.4)
            add_text(slide, x + 0.30, cy, w - 0.50, 0.28, [{"runs": [
                {"t": card[1], "size": 7.6, "color": MUTED},
            ]}], anchor=MSO_ANCHOR.MIDDLE)
            cy += 0.38
        elif ctype == "chips":
            cxs = x + 0.18
            for label, active in card[1]:
                cw = 0.10 + len(label) * 0.105
                add_chip(slide, cxs, cy, cw, 0.22, label,
                         BLUE if active else WHITE, WHITE if active else MUTED, 7.2)
                cxs += cw + 0.08
            cy += 0.32
        elif ctype == "card":
            label, tag, meta, sub, tag_color = card[1:]
            add_rect(slide, x + 0.18, cy, w - 0.36, 0.86, WHITE, LINE, rounded=True, radius=0.06)
            add_text(slide, x + 0.29, cy + 0.08, w - 0.75, 0.24, [{"runs": [
                {"t": label, "size": 8.8, "bold": True, "color": INK},
            ]}])
            add_chip(slide, x + w - 0.72, cy + 0.08, 0.46, 0.20, tag,
                     BLUE_SOFT if tag_color == BLUE else ORANGE_SOFT,
                     tag_color, 6.8)
            add_text(slide, x + 0.29, cy + 0.33, w - 0.48, 0.20, [{"runs": [
                {"t": meta, "size": 7.2, "color": MUTED},
            ]}])
            add_text(slide, x + 0.29, cy + 0.54, w - 0.48, 0.20, [{"runs": [
                {"t": sub, "size": 7.6, "bold": True, "color": INK2},
            ]}])
            cy += 0.95
        elif ctype == "rows":
            for name, meta in card[1]:
                add_rect(slide, x + 0.18, cy, w - 0.36, 0.32, WHITE, LINE, rounded=True, radius=0.3)
                add_circle(slide, x + 0.28, cy + 0.07, 0.18, LINE)
                add_text(slide, x + 0.52, cy, w - 0.95, 0.32, [{"runs": [
                    {"t": name, "size": 7.6, "bold": True, "color": INK},
                ]}], anchor=MSO_ANCHOR.MIDDLE)
                add_text(slide, x + w - 0.82, cy, 0.52, 0.32, [{"align": PP_ALIGN.RIGHT, "runs": [
                    {"t": meta, "size": 6.8, "color": MUTED},
                ]}], anchor=MSO_ANCHOR.MIDDLE)
                cy += 0.38
        elif ctype == "lines":
            for wfrac in card[1]:
                add_rect(slide, x + 0.20, cy, (w - 0.40) * wfrac, 0.08, LINE, rounded=True, radius=0.5)
                cy += 0.17
            cy += 0.12
        elif ctype == "info":
            for label, value in card[1]:
                add_text(slide, x + 0.20, cy, w - 0.40, 0.22, [{"runs": [
                    {"t": label, "size": 7.4, "color": MUTED},
                    {"t": "　" + value, "size": 7.6, "bold": True, "color": INK2},
                ]}])
                cy += 0.25
    if button:
        add_rect(slide, x + 0.18, y + h - 0.62, w - 0.36, 0.34, ORANGE, rounded=True, radius=0.3)
        add_text(slide, x + 0.18, y + h - 0.62, w - 0.36, 0.34, [{"align": PP_ALIGN.CENTER, "runs": [
            {"t": button, "size": 8.8, "bold": True, "color": WHITE},
        ]}], anchor=MSO_ANCHOR.MIDDLE)
    if footer:
        add_text(slide, x + 0.18, y + h - 0.24, w - 0.36, 0.18, [{"align": PP_ALIGN.CENTER, "runs": [
            {"t": footer, "size": 6.8, "color": MUTED},
        ]}])


def slide_app(prs):
    s = content_slide(prs, "一、做成了什么　3 / 7", "手机端：四个页面，学生和负责人都能上手",
                      "登录、看活动、报名、取消、看名单，主要操作都能在手机上完成。")
    add_phone(
        s, 0.72, 2.02, 2.15, 4.02, "活动广场", "全部活动 · 3 个进行中",
        [
            ("search", "搜索活动 / 社团"),
            ("card", "程序设计大赛", "报名中", "11-20 19:00 · 图书馆报告厅", "剩余 18 / 50", BLUE),
            ("card", "秋日校园摄影", "报名中", "11-22 14:00 · 中心湖", "剩余 6 / 30", BLUE),
            ("card", "迎新志愿者", "即将开始", "11-25 09:00 · 学生中心", "名额 40 · 未开放", ORANGE),
        ],
    )
    add_phone(
        s, 3.00, 2.02, 2.15, 4.02, "活动详情", "计算机学院 · 社团活动",
        [
            ("card", "程序设计大赛", "报名中", "11-20 19:00 · 图书馆报告厅", "剩余 18 / 50", BLUE),
            ("lines", [1.0, 0.92, 0.78]),
            ("info", [("报名截止", "11-19 18:00"), ("活动地点", "图书馆报告厅"), ("已报名", "32 人")]),
            ("lines", [0.65, 0.85]),
        ],
        button="立即报名", footer="报名成功后会收到站内消息",
    )
    add_phone(
        s, 5.28, 2.02, 2.15, 4.02, "报名名单", "32 / 50 · 报名已截止",
        [
            ("chips", [("全部", True), ("未签到", False), ("已签到", False)]),
            ("rows", [("王同学", "09:12"), ("李同学", "09:15"), ("陈同学", "09:21"),
                      ("赵同学", "09:28"), ("周同学", "09:31")]),
            ("lines", [0.7]),
        ],
        button="导出 Excel", footer="只有本社团负责人能看",
    )
    add_panel(s, 7.70, 2.02, 4.91, 3.82)
    add_panel_heading(s, 7.92, 2.16, 4.50, "手机端已经能做到的", BLUE, 14.5)
    add_bullets(s, 7.92, 2.58, 4.48, 2.40, [
        ("登录 / 记住登录　", "关闭应用再打开，不用重新登录"),
        ("列表 / 详情　", "加载中、没有数据、出错、下拉刷新都有提示"),
        ("报名 / 取消　", "按钮和剩余名额同步，失败有中文提示"),
        ("我的 / 名单　", "学生看自己报了什么，负责人看名单并导出"),
        ("统一网络请求　", "登录凭证、错误提示、防重复编号只写在一个地方"),
    ], size=10.2, gap=7)
    add_text(s, 7.92, 5.00, 4.48, 0.26, [{"runs": [
        {"t": "手机端三不　", "size": 9.5, "bold": True, "color": ORANGE},
        {"t": "不直接连数据库 · 不保存数据库密码 · 不自己决定报名是否成功", "size": 9.0, "color": INK2},
    ]}])
    add_note(s, 7.92, 5.48, 4.48, 0.28,
             "说明：图中是页面结构示意，实际运行以模拟器演示为准。", 8.2)
    add_takeaway(s, "手机端不是「画页面」：出错提示、权限入口、防重复都要在这一层做好。")
    add_speaker_notes(s, "左边三块是学生和负责人的主要操作：活动列表、活动详情、报名名单。"
                         "手机端只负责显示和点击，报名能不能成功由服务器判断；"
                         "所有网络请求都从一个地方发出，方便统一处理登录和错误提示。")


def slide_server(prs):
    s = content_slide(prs, "一、做成了什么　4 / 7", "服务器端：分成四块，规则只写一遍",
                      "活动状态、权限、防重复、名额扣减都在服务器端做，手机端不用再写一遍。")
    layers = [
        ("接口层", "接收手机端的请求，统一返回格式和错误提示", BLUE),
        ("功能层", "登录、活动、社团、报名、消息、权限", BLUE),
        ("规则层", "活动状态怎么变、谁能操作、名额怎么扣", ORANGE),
        ("数据层", "只负责读写数据库；以后换数据库，上面三层不用改", ORANGE),
    ]
    for i, (name, desc, color) in enumerate(layers):
        y = 2.10 + i * 0.90
        add_panel(s, 0.72, y, 6.68, 0.76)
        add_rect(s, 0.72, y, 0.07, 0.76, color)
        add_text(s, 0.95, y + 0.08, 1.15, 0.60, [{"runs": [
            {"t": name, "size": 11.5, "bold": True, "color": INK},
        ]}], anchor=MSO_ANCHOR.MIDDLE)
        add_text(s, 2.12, y + 0.06, 5.10, 0.64, [{"line": 1.08, "runs": [
            {"t": desc, "size": 10.0, "color": INK2},
        ]}], anchor=MSO_ANCHOR.MIDDLE)

    add_rect(s, 7.62, 2.10, 4.99, 3.56, INK, rounded=True, radius=0.03)
    add_text(s, 7.86, 2.24, 4.50, 0.28, [{"runs": [
        {"t": "报名时，服务器按顺序检查", "size": 11, "bold": True, "color": "FFC17A"},
    ]}])
    checks = [
        ("1", "活动现在可以报名吗？"),
        ("2", "这个同学已经报过名吗？"),
        ("3", "活动还有名额吗？"),
        ("4", "都通过：扣 1 个名额、写报名记录、发消息"),
    ]
    for i, (num, text) in enumerate(checks):
        y = 2.62 + i * 0.52
        add_circle(s, 7.88, y + 0.04, 0.28, ORANGE, num, WHITE, 9.5)
        add_text(s, 8.30, y, 4.00, 0.34, [{"runs": [
            {"t": text, "size": 10.5, "color": WHITE if i == 3 else "E8EAED"},
        ]}])
    add_text(s, 7.88, 4.88, 4.45, 0.55, [{"line": 1.12, "runs": [
        {"t": "任何一步失败，这次报名全部撤销，名额不变。", "size": 10.2, "bold": True, "color": "FFC17A"},
    ]}])
    add_text(s, 7.88, 5.34, 4.45, 0.24, [{"runs": [
        {"t": "防重复：同一个请求编号重试，只算一次。", "size": 8.8, "color": "B9C0C8"},
    ]}])
    add_note(s, 0.95, 5.80, 6.30, 0.24,
             "上层能用下层，下层不能反过来用上层；规则部分不碰数据库和网络。", 8.8)
    add_takeaway(s, "手机端只负责展示，报名能不能成功由服务器说了算。")
    add_speaker_notes(s, "服务器端分四块：接口层负责收发请求，功能层放具体功能，规则层管活动状态、"
                         "权限和名额，数据层只读写数据库。右边是报名时的检查顺序，"
                         "任何一步不通过就整体撤销，不会出现「名额扣了但报名没记上」。")


def slide_data(prs):
    s = content_slide(prs, "一、做成了什么　5 / 7", "数据库：从发活动到看名单，每一步都记下来了",
                      "一个活动从草稿到名单，每一步都真的存进数据库，不用手工改数据。")
    steps = [
        ("01", "发布活动",
         "负责人填写活动，先存草稿，再点发布；只允许「草稿 → 报名中」这一步；别的社团负责人不能操作。",
         "负责人 / 管理员"),
        ("02", "学生报名",
         "检查报名时间 → 检查是否重复 → 扣名额 → 写报名记录 → 发消息；这些步骤一起成功或一起失败。",
         "学生"),
        ("03", "查看名单",
         "负责人按活动查看名单，可以筛选和导出；只能看到自己社团的名单。",
         "负责人 / 管理员"),
    ]
    for i, (num, title, body, who) in enumerate(steps):
        x = 0.72 + i * 3.98
        add_panel(s, x, 2.05, 3.72, 1.78)
        add_circle(s, x + 0.18, 2.20, 0.46, BLUE if i < 2 else ORANGE, num, WHITE, 10.5)
        add_text(s, x + 0.76, 2.22, 2.75, 0.30, [{"runs": [
            {"t": title, "size": 14, "bold": True, "color": INK},
        ]}])
        add_note(s, x + 0.76, 2.52, 2.75, 0.20, who, 8, MUTED)
        add_text(s, x + 0.18, 2.82, 3.38, 0.88, [{"line": 1.12, "runs": [
            {"t": body, "size": 9.0, "color": INK2},
        ]}])
        if i < 2:
            add_arrow(s, x + 3.77, 2.86, 0.18, 0.26, BLUE)

    add_rect(s, 0.72, 4.02, 11.89, 0.52, INK, rounded=True, radius=0.12)
    add_text(s, 0.95, 4.02, 11.45, 0.52, [{"runs": [
        {"t": "这一串操作是一个整体　", "size": 10, "bold": True, "color": "FFC17A"},
        {"t": "要么全部成功，要么全部撤销，不会出现「名额扣了但报名没记上」。", "size": 10.5, "color": WHITE},
    ]}], anchor=MSO_ANCHOR.MIDDLE)

    add_panel(s, 0.72, 4.78, 7.05, 1.22)
    add_panel_heading(s, 0.92, 4.88, 6.70, "6 张数据表", BLUE, 12.5)
    table_names = ["app_user", "club", "activity", "activity_sign", "message", "audit_log"]
    for i, name in enumerate(table_names):
        add_chip(s, 0.92 + (i % 3) * 2.25, 5.24 + (i // 3) * 0.36, 2.05, 0.26, name, WHITE, INK2, 8.5)
    add_panel(s, 7.98, 4.78, 4.63, 1.22, ORANGE_SOFT)
    add_panel_heading(s, 8.18, 4.88, 4.25, "三道保险", ORANGE, 12.5)
    add_bullets(s, 8.18, 5.20, 4.25, 0.72, [
        ("一条语句扣名额　", "判断和扣减同时完成"),
        ("数据库唯一限制　", "同一个人不能重复报名"),
        ("检查规则　", "状态、名额范围、报名时间必须合法"),
    ], size=8.4, gap=2, line=1.02)
    add_takeaway(s, "完整流程能走通的标志：任何一个活动，从草稿到名单都能走完。")
    add_speaker_notes(s, "这一页是完整流程的三步。重点是第二步：报名不是一个请求只写一张表，"
                         "而是扣名额、写报名、发消息一起完成，任何一步失败就全部撤销。"
                         "数据库还有三道保险：一条语句扣名额、唯一限制、检查规则。")


def slide_concurrency(prs):
    s = content_slide(prs, "一、做成了什么　6 / 7", "最难的一关：很多人同时报名，名额不会多",
                      "这是整个项目最难的地方，也是第 6 周重点测的内容。")
    add_panel(s, 0.72, 2.02, 5.84, 1.56)
    add_text(s, 0.92, 2.12, 5.40, 0.28, [{"runs": [
        {"t": "✕　常见错误做法：先查再改", "size": 12.5, "bold": True, "color": MUTED},
    ]}])
    add_text(s, 0.92, 2.46, 5.42, 1.02, [
        {"space_after": 3, "runs": [{"t": "两个人同时看到「还剩 1 个名额」，", "size": 10.5, "color": INK2}]},
        {"space_after": 3, "runs": [{"t": "都以为能报，于是两个人都成功了。", "size": 10.5, "color": INK2}]},
        {"runs": [{"t": "结果：名额变成 −1，名单多出一个人。", "size": 10.5, "bold": True, "color": ORANGE}]},
    ])
    add_rect(s, 6.78, 2.02, 5.83, 1.56, BLUE_SOFT)
    add_text(s, 6.98, 2.12, 5.40, 0.28, [{"runs": [
        {"t": "✓　我们的做法：一条语句同时判断和扣减", "size": 12.5, "bold": True, "color": BLUE},
    ]}])
    add_text(s, 6.98, 2.46, 5.40, 1.02, [
        {"space_after": 3, "runs": [{"t": "只有「活动在报名中」并且「名额 > 0」时，", "size": 10.2, "color": INK2}]},
        {"space_after": 3, "runs": [{"t": "数据库才把名额减 1；一次只让一个人成功。", "size": 10.2, "color": INK2}]},
        {"runs": [{"t": "如果一行都没改到 → 名额已满，直接返回提示。", "size": 10.2, "bold": True, "color": BLUE},
        ]},
    ])

    defenses = [
        ("保险 1 · 判断和扣减不分开", "不会两个人同时看到最后一个名额"),
        ("保险 2 · 数据库唯一限制", "同一个人同一活动只能有一条有效报名"),
        ("保险 3 · 防重复编号", "网络重试不会重复扣名额"),
    ]
    for i, (head, body) in enumerate(defenses):
        x = 0.72 + i * 3.98
        add_rect(s, x, 3.76, 3.72, 0.66, BG, rounded=True, radius=0.08)
        add_text(s, x + 0.14, 3.84, 3.45, 0.24, [{"runs": [
            {"t": head, "size": 10.2, "bold": True, "color": BLUE},
        ]}])
        add_text(s, x + 0.14, 4.08, 3.45, 0.26, [{"runs": [
            {"t": body, "size": 8.6, "color": INK2},
        ]}])

    results = [
        (str(METRICS["concurrency"]), "人同时报名"),
        (str(METRICS["seats"]), "个名额"),
        (str(METRICS["success"]), "人报名成功"),
        (str(METRICS["oversell"]), "超报 / 重复"),
    ]
    for i, (value, label) in enumerate(results):
        x = 0.72 + i * 3.01
        add_panel(s, x, 4.66, 2.87, 0.98)
        add_text(s, x + 0.16, 4.74, 1.15, 0.46, [{"runs": [
            {"t": value, "size": 27, "bold": True, "color": ORANGE if i == 3 else BLUE},
        ]}])
        add_text(s, x + 1.22, 4.84, 1.50, 0.28, [{"runs": [
            {"t": label, "size": 10, "bold": True, "color": INK},
        ]}])
    add_note(s, 0.72, 5.72, 11.89, 0.24,
             f"95% 的请求在 {METRICS['p95_ms']} 毫秒内返回　·　"
             f"没抢到的 {METRICS['concurrency'] - METRICS['seats']} 人都收到「名额已满」　·　"
             "取消后可以重新报名　·　测试可以重复跑",
             9, MUTED)
    add_takeaway(s, "把正确性交给数据库规则，不靠程序员记得加锁。")
    add_speaker_notes(s, "左边是错误的先查再改：两个人都看到最后一个名额，都成功了，名额就变成负数。"
                         "我们的做法是一条语句同时判断和扣减，数据库一次只让一个人成功。"
                         f"测试结果：{METRICS['concurrency']} 人同时抢 {METRICS['seats']} 个名额，"
                         f"成功刚好 {METRICS['success']} 人，0 超报，95% 的请求在 200 毫秒内返回。")


def slide_test(prs):
    s = content_slide(prs, "一、做成了什么　7 / 7", "测试：正常、边界、出错情况都试过",
                      "不是只点一遍正常流程；每种出错情况都有测试。")
    rows = [
        ["测试项", "试了什么", "结果"],
        ["活动状态", "草稿→报名中→报名结束→已结束；跳步、下架后再发布", "不合法的变化全部被拒绝"],
        ["同时报名", f"{METRICS['concurrency']} 人同时抢 {METRICS['seats']} 个名额；取消后重报；连续点两次", f"{METRICS['success']} 人成功，0 超报，0 重复"],
        ["防重复", "同一个请求编号重试；换人 / 换活动复用编号；取消后重试", "重试返回第一次结果；编号复用被拒绝"],
        ["权限", "学生改别人的报名、负责人管别的社团、管理员操作", "没有权限的操作全部被拒绝"],
        ["出错情况", "名额满、报名截止、活动不存在、重复取消", "都返回看得懂的中文提示"],
    ]
    add_table(s, 0.72, 2.05, [0.95, 5.35, 3.25], rows,
              row_height=0.66, body_size=8.8, header_size=9.6, center_cols=(0,),
              header_height=0.50)
    add_panel(s, 10.42, 2.05, 2.19, 3.62, INK)
    add_text(s, 10.58, 2.18, 1.90, 0.26, [{"runs": [
        {"t": "测试情况", "size": 10, "bold": True, "color": "FFC17A"},
    ]}])
    snap = [
        ("5 组", "测试全部通过"),
        (f"{METRICS['bugs_found']} 个", "问题已发现"),
        (f"{METRICS['bugs_fixed']} 个", "已经修好"),
        (f"{METRICS['bugs_left']} 个", "遗留，第 10 周前清理"),
    ]
    for i, (value, label) in enumerate(snap):
        y = 2.52 + i * 0.76
        add_text(s, 10.58, y, 1.86, 0.34, [{"runs": [
            {"t": value, "size": 18, "bold": True, "color": WHITE},
        ]}])
        add_text(s, 10.58, y + 0.30, 1.86, 0.22, [{"runs": [
            {"t": label, "size": 8.4, "color": "B9C0C8"},
        ]}])
    add_takeaway(s, "把这些测试留下来，后面加功能时才不会把已经跑通的流程弄坏。")
    add_speaker_notes(s, "测试按五组走：活动状态、同时报名、防重复、权限、出错情况。"
                         "结果是 5 组测试全部通过，发现 11 个问题，修好 9 个，剩 2 个都不影响主流程，"
                         "第 10 周停止加功能前会清理掉。")


def slide_problems(prs):
    s = content_slide(prs, "二、踩过的坑　1 / 2", "问题主要出在开发工具和前后端配合上",
                      "6 个主要问题，5 个已经解决，1 个要靠以后每周坚持。")
    rows = [
        ["问题", "影响", "解决办法", "状态"],
        ["仓颉开发工具在这台电脑上一启动就崩溃",
         "代码能编译，但程序跑不起来，没法联调",
         "用备用脚本编译；换到 DevEco 自带的仓颉工具链 / 云服务器上联调；关键功能不用特殊语法", "已解决"],
        ["数据库的唯一限制报错被当成系统错误",
         "重复报名时用户看到系统错误",
         "在数据访问层把这类错误翻译成「已报名」「请求编号重复」", "已解决"],
        ["报名和取消的加锁顺序不一致",
         "同时操作时偶尔卡住或超时",
         "统一先锁活动、再锁报名记录；归还名额时检查不超过总名额", "已解决"],
        ["防重复编号被不同活动 / 不同用户复用",
         "可能返回别人的报名结果",
         "服务器核对编号对应的用户和活动，对不上就拒绝", "已解决"],
        ["报名成功后手机端名额没更新",
         "用户看到旧数字，容易重复点",
         "报名结果带回最新名额；详情页更新，列表下拉刷新", "已解决"],
        ["三个人同时改接口字段",
         "手机端返工，联调变慢",
         "第 2 周把接口定死；以后只加字段不改字段；每周三一起联调", "长期执行"],
    ]
    add_table(s, 0.72, 2.05, [2.75, 2.45, 4.80, 1.89], rows,
              row_height=0.57, body_size=8.2, header_size=9.2,
              center_cols=(3,), status_col=3, header_height=0.48)
    add_text(s, 0.72, 6.22, 11.89, 0.34, [{"runs": [
        {"t": "共同点　", "size": 10.5, "bold": True, "color": ORANGE},
        {"t": "问题都出在工具和配合上，功能方向已经被完整流程验证——这是中期最想让老师看的部分。",
         "size": 10.5, "color": INK2},
    ]}])
    add_speaker_notes(s, "这一页不遮问题。最影响进度的是仓颉开发工具在这台电脑上启动崩溃，"
                         "我们把它当成环境问题处理，用备用脚本和换工具链绕过去，没有让它卡住功能开发。"
                         "其余几个都是同时报名和防重复带来的，已经写进测试，后面不会复发。"
                         "最后一条是三个人同时改接口，靠第 2 周定死接口、以后只加不改来控制。")


def slide_gaps(prs):
    s = content_slide(prs, "二、踩过的坑　2 / 2", "还没做完的，和可能影响进度的",
                      "后面最大的风险不是技术，而是功能越加越多、上架时间不够。")
    add_panel(s, 0.72, 2.05, 5.80, 3.62)
    add_panel_heading(s, 0.94, 2.18, 5.40, "还没做完的（如实说）", MUTED, 14)
    add_bullets(s, 0.94, 2.56, 5.35, 2.05, [
        ("功能　", "消息、统计、管理员后台还是空的，安排在第 7–9 周"),
        ("工程　", "服务器还没真正联网对外服务，正式上线和监控还没做"),
        ("质量　", "只在 1 台真机上试过；弱网、无障碍、深色模式还没系统测试"),
        ("上架　", "隐私政策、审核账号、截图和文案还没准备"),
        ("时间　", "后 6 周任务更密，需要提前动手，不能拖到最后两周"),
    ], size=10.2, gap=10, line=1.15)
    add_rect(s, 0.94, 4.62, 5.36, 0.64, WHITE, rounded=True, radius=0.08)
    add_text(s, 1.10, 4.68, 5.05, 0.52, [{"line": 1.12, "runs": [
        {"t": "结论　", "size": 9.8, "bold": True, "color": BLUE},
        {"t": "主流程没有欠账；欠的是扩展功能与上架材料，已全部排进第 7–12 周。", "size": 9.6, "color": INK2},
    ]}])

    add_panel(s, 6.82, 2.05, 5.79, 3.62, ORANGE_SOFT)
    add_panel_heading(s, 7.04, 2.18, 5.40, "可能的问题和办法", ORANGE, 14)
    risks = [
        ("仓颉开发工具不稳定", "固定一台联调电脑 + 备用编译脚本；关键功能不用特殊语法"),
        ("上架审核时间长", "第 11 周开始内测，材料提前到第 9 周准备，留 1 周缓冲"),
        ("三个人时间冲突", "任务拆到 2–3 天；关键任务提前做；每周三一起联调"),
        ("功能越加越多", "第 6 周后不再加可选功能；第 10 周停止加功能，只修 bug"),
    ]
    for i, (head, body) in enumerate(risks):
        y = 2.58 + i * 0.76
        add_text(s, 7.04, y, 5.35, 0.26, [{"runs": [
            {"t": "·　" + head, "size": 10.5, "bold": True, "color": INK},
        ]}])
        add_text(s, 7.18, y + 0.27, 5.20, 0.28, [{"runs": [
            {"t": body, "size": 9.2, "color": INK2},
        ]}])
    add_takeaway(s, "剩下的不是「能不能做」，而是「能不能控制住范围」。")
    add_speaker_notes(s, "功能缺口很清楚：消息、统计、管理员后台，正好对应第 7 到第 9 周。"
                         "风险里最需要老师帮我们把关的是上架时间和学校主体资质，这个放在最后一页问。")


def slide_plan_79(prs):
    s = content_slide(prs, "三、后面怎么干　1 / 3", "第 7–9 周：补上消息、统计和管理员功能",
                      "还是三个人分头做，每周日必须有一个能当场演示的东西。")
    rows = [
        ["周", "手机端 A", "服务器端 B", "数据库 C", "周末要拿出什么"],
        ["7", "消息中心、未读红点、通知权限",
         "消息功能、定时提醒、群发权限",
         "消息表 / 发送记录、失败重试",
         "报名、取消、审核都有站内消息；推送失败不影响报名"],
        ["8", "统计页面、图表、空状态",
         "统计接口、按角色过滤",
         "统计查询、查询提速",
         "负责人只看本社团，管理员看全校；数字和名单一致"],
        ["9", "管理员页面、审核 / 下架 / 举报",
         "审核下架、操作日志、账号注销",
         "操作日志表、备份策略",
         "下架后学生不能报名；日志能查到谁、什么时候、对谁操作"],
    ]
    add_table(s, 0.72, 2.02, [0.55, 2.55, 2.70, 2.55, 3.54], rows,
              row_height=1.10, body_size=8.8, header_size=9.4, center_cols=(0,),
              header_height=0.50)
    add_rect(s, 0.72, 6.10, 0.90, 0.05, ORANGE)
    add_text(s, 0.72, 6.30, 11.89, 0.40, [{"runs": [
        {"t": "要记住的三个时间点　", "size": 10.5, "bold": True, "color": ORANGE},
        {"t": "第 6 周完整流程 ✓　　→　　第 10 周停止加功能　　→　　第 12 周提交上架", "size": 11.5, "bold": True, "color": INK},
    ]}])
    add_speaker_notes(s, "第 7 到第 9 周是补功能的三周：第 7 周消息、第 8 周统计、第 9 周管理员后台。"
                         "每周日要拿出什么写在最右列，周末演示就按这个来，不靠口头汇报。")


def slide_plan_1012(prs):
    s = content_slide(prs, "三、后面怎么干　2 / 3", "第 10–12 周：停止加功能、测试、上架",
                      "第 10 周以后只修 bug，不加功能；把时间留给测试和审核。")
    rows = [
        ["周", "手机端 A", "服务器端 B", "数据库 C", "周末要拿出什么"],
        ["10", "界面打磨、弱网 / 出错情况、无障碍",
         "接口测试、错误提示统一、边界情况",
         "安全检查（越权 / 恶意输入 / 密码）、数据恢复演练",
         "停止加功能 + 问题清单；只修 bug，不加功能"],
        ["11", "演示脚本、截图、答辩材料、用户反馈",
         "性能优化、代码定稿、文档",
         "正式上线、监控报警、审核账号、内测安装包",
         "候选版本 + 上架材料；新手机安装一遍能走通"],
        ["12", "答辩演示、整理用户反馈",
         "最后回归、版本号和更新说明",
         "提交华为应用市场、跟进审核",
         "提交上架 + 答辩；至少留 1 周审核缓冲"],
    ]
    add_table(s, 0.72, 2.02, [0.55, 2.55, 2.70, 2.55, 3.54], rows,
              row_height=1.10, body_size=8.8, header_size=9.4, center_cols=(0,),
              header_height=0.50)
    add_rect(s, 0.72, 6.10, 0.90, 0.05, BLUE)
    add_text(s, 0.72, 6.30, 11.89, 0.40, [{"runs": [
        {"t": "我们定死的规矩　", "size": 10.5, "bold": True, "color": BLUE},
        {"t": "第 10 周起停止加功能；新需求先记下来，不插队。", "size": 11.5, "bold": True, "color": INK},
    ]}])
    add_speaker_notes(s, "第 10 周停止加功能，第 11 周出候选版本并开始内测，第 12 周提交审核和答辩。"
                         "留一周审核缓冲，这是开题时就定下的，现在不改。上架材料提前到第 9 周开始准备。")


def slide_guard(prs):
    s = content_slide(prs, "三、后面怎么干　3 / 3", "怎么保证后 6 周按时完成",
                      "每周怎么配合，以及想请老师帮忙看看的三个问题。")
    add_panel(s, 0.72, 2.05, 5.80, 3.62)
    add_panel_heading(s, 0.94, 2.18, 5.40, "每周怎么配合", BLUE, 14)
    rhythm = [
        ("周一　", "演示上周成果，现场跑，不口头汇报"),
        ("周三　", "三个人一起联调，接口有变化当场确认"),
        ("周五　", "互相看代码，下周任务分到人和天"),
    ]
    for i, (day, body) in enumerate(rhythm):
        y = 2.58 + i * 0.50
        add_text(s, 0.94, y, 0.75, 0.30, [{"runs": [
            {"t": day, "size": 10.5, "bold": True, "color": BLUE},
        ]}])
        add_text(s, 1.72, y, 4.55, 0.30, [{"runs": [
            {"t": body, "size": 10.2, "color": INK2},
        ]}])
    add_text(s, 0.94, 4.18, 5.35, 1.30, [
        {"space_after": 5, "line": 1.12, "runs": [
            {"t": "规矩一　", "size": 9.8, "bold": True, "color": ORANGE},
            {"t": "改接口必须提前说，只能加字段，不能改已有字段。", "size": 9.8, "color": INK2},
        ]},
        {"space_after": 5, "line": 1.12, "runs": [
            {"t": "规矩二　", "size": 9.8, "bold": True, "color": ORANGE},
            {"t": "新功能必须带一个出错情况的测试，否则不算完成。", "size": 9.8, "color": INK2},
        ]},
        {"line": 1.12, "runs": [
            {"t": "规矩三　", "size": 9.8, "bold": True, "color": ORANGE},
            {"t": "第 10 周后只修 bug，新需求先记下来。", "size": 9.8, "color": INK2},
        ]},
    ])

    add_panel(s, 6.82, 2.05, 5.79, 3.62, ORANGE_SOFT)
    add_panel_heading(s, 7.04, 2.18, 5.40, "想请老师帮忙看看的三个问题", ORANGE, 14)
    questions = [
        ("中期演示要到什么程度？",
         "需要真机 + 真实数据库吗？目前是模拟器 + 内存数据，数据库版本已经准备好，可以随时切换。"),
        ("上架要准备的材料",
         "学校资质、隐私政策模板有没有建议？我们计划第 9 周开始准备。"),
        ("统计范围",
         "需要和学校现有活动 / 社团系统对接吗？还是先按平台内的数据统计？"),
    ]
    for i, (head, body) in enumerate(questions):
        y = 2.58 + i * 0.98
        add_circle(s, 7.04, y + 0.02, 0.28, ORANGE, str(i + 1), WHITE, 10)
        add_text(s, 7.44, y, 4.95, 0.26, [{"runs": [
            {"t": head, "size": 10.5, "bold": True, "color": INK},
        ]}])
        add_text(s, 7.44, y + 0.28, 4.95, 0.56, [{"line": 1.10, "runs": [
            {"t": body, "size": 8.8, "color": INK2},
        ]}])
    add_takeaway(s, "范围控制得住，12 周才完成得了。")
    add_speaker_notes(s, "最后是保障机制：周一演示、周三联调、周五互相看代码，三条纪律。"
                         "另外有三个问题想请老师现场指导：中期演示要到什么程度、上架主体和材料、统计范围。")


def slide_end(prs):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    for ph in list(s.placeholders):
        ph._element.getparent().remove(ph._element)
    s.background.fill.solid()
    s.background.fill.fore_color.rgb = rgb(WHITE)
    add_text(s, 1.15, 1.55, 11.20, 0.34, [{"runs": [
        {"t": "中期答辩 · 第 1–6 周", "size": 12, "bold": True, "color": ORANGE},
    ]}])
    add_text(s, 1.15, 2.02, 11.20, 1.70, [
        {"space_after": 8, "line": 1.12, "runs": [
            {"t": "第 6 周，完整流程已经跑通；", "size": 34, "bold": True, "color": INK},
        ]},
        {"line": 1.12, "runs": [
            {"t": "第 12 周，把它交给全校同学用。", "size": 34, "bold": True, "color": INK},
        ]},
    ])
    add_rect(s, 1.15, 4.00, 1.10, 0.06, ORANGE)
    add_text(s, 1.15, 4.30, 11.20, 0.70, [
        {"runs": [{"t": "谢谢各位老师，请批评指正。", "size": 19, "bold": True, "color": INK2}]},
        {"space_before": 8, "runs": [
            {"t": "林家俊　严一凡　朱一言　·　2026 年 11 月", "size": 12, "color": MUTED},
        ]},
    ])
    add_speaker_notes(s, "汇报到这里，谢谢老师。接下来我们按第 7 到第 12 周的计划推进，"
                         "也请老师在上架主体、中期演示范围和统计范围上给一些建议。")


def main(dst):
    prs = Presentation()
    prs.slide_width = Inches(13.333)
    prs.slide_height = Inches(7.5)

    slide_cover(prs)
    slide_agenda(prs)
    slide_progress(prs)
    slide_overview(prs)
    slide_app(prs)
    slide_server(prs)
    slide_data(prs)
    slide_concurrency(prs)
    slide_test(prs)
    slide_problems(prs)
    slide_gaps(prs)
    slide_plan_79(prs)
    slide_plan_1012(prs)
    slide_guard(prs)
    slide_end(prs)

    assert len(prs.slides) == TOTAL_SLIDES
    for i, slide in enumerate(prs.slides, 1):
        if i == 1 or i == TOTAL_SLIDES:
            continue
        add_footer(slide, i)

    prs.save(dst)
    print(f"saved {dst} · {len(prs.slides)} slides")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "校园活动与社团管理_中期答辩.pptx")
