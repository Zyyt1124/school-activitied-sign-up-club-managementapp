# -*- coding: utf-8 -*-
"""按老师反馈改开题 PPT：
1) 增加仓颉语言特色页
2) 增加端云边界 / 数据库交互 / 上架审核页
3) 分工从 8 周细化到 12 周（两页）
4) 统一页脚、色板、字体
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
INK = "1F242B"
INK2 = "3C424A"
MUTED = "8B939D"
BLUE = "2E6FB8"
ORANGE = "C16B2E"
BG = "F5F7F9"
LINE = "DEE2E7"
WHITE = "FFFFFF"
ORANGE_LIGHT = "FFC17A"


def rgb(hex_value):
    return RGBColor.from_string(hex_value)


def style_run(run, size, bold=False, color=INK2, font=FONT):
    run.font.name = font
    run.font.size = Pt(size)
    run.font.bold = bold
    run.font.color.rgb = rgb(color)
    rPr = run._r.get_or_add_rPr()
    for tag in ("a:ea", "a:cs", "a:sym"):
        el = rPr.find(qn(tag))
        if el is None:
            el = etree.SubElement(rPr, qn(tag))
        el.set("typeface", font)


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
        style_run(run, rd.get("size", 12), rd.get("bold", False), rd.get("color", INK2))


def rebuild_text_frame(shape, paras):
    tf = shape.text_frame
    tf.word_wrap = True
    ps = list(tf.paragraphs)
    for p in ps[1:]:
        p._p.getparent().remove(p._p)
    first = tf.paragraphs[0]
    for r in list(first.runs):
        r._r.getparent().remove(r._r)
    _fill_para(first, paras[0])
    for spec in paras[1:]:
        _fill_para(tf.add_paragraph(), spec)


def set_para(para, runs, align=None, space_after=None, line=None):
    for r in list(para.runs):
        r._r.getparent().remove(r._r)
    if align is not None:
        para.alignment = align
    if space_after is not None:
        para.space_after = Pt(space_after)
    if line is not None:
        para.line_spacing = line
    for rd in runs:
        run = para.add_run()
        run.text = rd["t"]
        style_run(run, rd.get("size", 12), rd.get("bold", False), rd.get("color", INK2))


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


def add_rect(slide, x, y, w, h, fill, line=None):
    shp = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(x), Inches(y), Inches(w), Inches(h))
    shp.fill.solid()
    shp.fill.fore_color.rgb = rgb(fill)
    if line:
        shp.line.color.rgb = rgb(line)
        shp.line.width = Pt(0.75)
    else:
        shp.line.fill.background()
    shp.shadow.inherit = False
    return shp


def get_shape(slide, name):
    for shp in slide.shapes:
        if shp.name == name:
            return shp
    raise KeyError(f"shape {name!r} not found in slide")


def content_slide(prs, section, title, subtitle):
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    for ph in list(slide.placeholders):
        ph._element.getparent().remove(ph._element)
    slide.background.fill.solid()
    slide.background.fill.fore_color.rgb = rgb(WHITE)
    add_text(slide, 0.72, 0.50, 11.89, 0.28,
             [{"runs": [{"t": section, "size": 11, "color": MUTED}]}])
    add_text(slide, 0.72, 0.82, 11.89, 0.60,
             [{"runs": [{"t": title, "size": 26, "bold": True, "color": INK}]}])
    add_rect(slide, 0.72, 1.40, 0.85, 0.05, BLUE)
    add_text(slide, 0.72, 1.72, 11.89, 0.34,
             [{"runs": [{"t": subtitle, "size": 15, "bold": True, "color": ORANGE}]}])
    return slide


def add_takeaway(slide, text):
    add_rect(slide, 0.72, 6.16, 0.90, 0.05, ORANGE)
    add_text(slide, 0.72, 6.38, 11.89, 0.52, [{"runs": [
        {"t": "一句话　", "size": 11.5, "bold": True, "color": ORANGE},
        {"t": text, "size": 15, "bold": True, "color": INK},
    ]}])


def add_panel(slide, x, y, w, h, fill=BG):
    add_rect(slide, x, y, w, h, fill)


def add_panel_heading(slide, x, y, w, text, color=BLUE, size=15):
    add_text(slide, x, y, w, 0.32, [{"runs": [{"t": text, "size": size, "bold": True, "color": color}]}])


def set_cell_no_border(cell):
    tcPr = cell._tc.get_or_add_tcPr()
    for tag in ("a:lnL", "a:lnR", "a:lnT", "a:lnB"):
        for el in tcPr.findall(qn(tag)):
            tcPr.remove(el)
    for index, tag in enumerate(("a:lnL", "a:lnR", "a:lnT", "a:lnB")):
        ln = etree.Element(qn(tag))
        ln.set("w", "0")
        ln.set("cap", "flat")
        ln.set("cmpd", "sng")
        ln.set("algn", "ctr")
        solid = etree.SubElement(ln, qn("a:solidFill"))
        clr = etree.SubElement(solid, qn("a:srgbClr"))
        clr.set("val", "000000")
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
        tcPr.insert(index, ln)


def add_table(slide, x, y, col_widths, rows, row_height=0.575, body_size=9.5, header_size=10):
    nrows = len(rows)
    ncols = len(col_widths)
    width = sum(col_widths)
    shape = slide.shapes.add_table(nrows, ncols, Inches(x), Inches(y), Inches(width), Inches(row_height * nrows))
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
        table.rows[ri].height = Inches(row_height)
        for ci, value in enumerate(row):
            cell = table.cell(ri, ci)
            set_cell_no_border(cell)
            cell.margin_left = Inches(0.08)
            cell.margin_right = Inches(0.07)
            cell.margin_top = Inches(0.03)
            cell.margin_bottom = Inches(0.03)
            cell.vertical_anchor = MSO_ANCHOR.MIDDLE
            cell.fill.solid()
            cell.fill.fore_color.rgb = rgb(LINE if ri == 0 else WHITE)
            tf = cell.text_frame
            tf.word_wrap = True
            p = tf.paragraphs[0]
            for r in list(p.runs):
                r._r.getparent().remove(r._r)
            run = p.add_run()
            run.text = str(value)
            style_run(run, header_size if ri == 0 else body_size, ri == 0, INK if ri == 0 else INK2)
            p.alignment = PP_ALIGN.CENTER if ci == 0 else PP_ALIGN.LEFT
    return shape


def remove_shape(shape):
    shape._element.getparent().remove(shape._element)


def rebuild_footer(slide, page):
    for shp in slide.shapes:
        if shp.has_text_frame and "社团管理平台 开题报告" in shp.text_frame.text:
            rebuild_text_frame(shp, [{"align": PP_ALIGN.RIGHT, "runs": [
                {"t": "社团管理平台 开题报告　", "size": 9, "color": MUTED},
                {"t": str(page), "size": 10, "bold": True, "color": MUTED},
            ]}])


def main(src, dst):
    prs = Presentation(src)
    slides = list(prs.slides)

    # ---------- slide 1: 汇报日期 ----------
    set_para(slides[0].shapes[2].text_frame.paragraphs[1], [
        {"t": "汇报日期", "size": 13, "color": MUTED},
        {"t": "：", "size": 13, "color": MUTED},
        {"t": "【2026 年11月13日】", "size": 13, "bold": True, "color": INK2},
    ])

    # ---------- slide 5: 技术可行性 ----------
    s5 = slides[4]
    table5 = None
    for shp in s5.shapes:
        if shp.has_table:
            table5 = shp
            break
    if table5 is not None:
        rows_new = [
            ["层", "选型", "理由"],
            ["界面", "HarmonyOS 26 Stage 模型 + ArkTS / ArkUI 原生", "非 Web 套壳，性能与生态一致"],
            ["业务逻辑", "仓颉语言（云侧业务服务 + 端侧 C FFI 可选）", "强类型、模式匹配；状态机 / 权限 / 并发校验清晰"],
            ["数据存储", "华为云数据库（PostgreSQL / GaussDB）", "仅云侧仓颉服务经私网访问，事务保证一致性"],
        ]
        for ri, row in enumerate(rows_new):
            for ci, value in enumerate(row):
                cell = table5.table.cell(ri, ci)
                set_cell_no_border(cell)
                tf = cell.text_frame
                p = tf.paragraphs[0]
                for r in list(p.runs):
                    r._r.getparent().remove(r._r)
                run = p.add_run()
                run.text = value
                style_run(run, 12.5, ri == 0, INK if ri == 0 else INK2)
                p.alignment = PP_ALIGN.LEFT
    rebuild_text_frame(get_shape(s5, "AutoShape 8"), [
        {"space_after": 7, "runs": [
            {"t": "核心业务　", "size": 13, "bold": True, "color": ORANGE},
            {"t": "仓颉实现报名核心逻辑：名额并发锁、状态流转、权限校验。", "size": 15, "bold": True, "color": INK},
        ]},
        {"runs": [
            {"t": "依据：报名是高并发场景，事务内条件扣减防止超报；端侧不直连数据库，权限分层保障三方用户各尽其职。",
             "size": 12, "color": INK2},
        ]},
    ])

    # ---------- slide 6: 可行性保障 ----------
    s6 = slides[5]
    resource = get_shape(s6, "AutoShape 7")
    ps = resource.text_frame.paragraphs
    set_para(ps[2], [
        {"t": "数据　", "size": 12.5, "bold": True, "color": BLUE},
        {"t": "用户 / 社团 / 活动 / 报名数据全部存华为云数据库，", "size": 11.5, "color": INK2},
    ], space_after=9)
    set_para(ps[3], [
        {"t": "由云侧仓颉服务统一访问，端侧不持有数据库凭据。", "size": 11.5, "color": INK2},
    ], line=1.25)
    set_para(ps[4], [
        {"t": "团队　", "size": 12.5, "bold": True, "color": BLUE},
        {"t": "3 人 12 周，「前端 ArkTS / 仓颉业务 / 数据库联调」并行；", "size": 11.5, "color": INK2},
    ], space_after=9)
    set_para(ps[5], [
        {"t": "每周均有可运行交付物，第 6 周即产出最小闭环。", "size": 11.5, "color": INK2},
    ], line=1.25)
    env_para = resource.text_frame.add_paragraph()
    _fill_para(env_para, {"line": 1.2, "runs": [
        {"t": "环境　", "size": 12.5, "bold": True, "color": BLUE},
        {"t": "DevEco Studio 26 + HarmonyOS SDK 26 + 仓颉 1.0.5，本地已完成最小工程编译验证。", "size": 11.5, "color": INK2},
    ]})

    risk = get_shape(s6, "AutoShape 8")
    risk_para = risk.text_frame.add_paragraph()
    _fill_para(risk_para, {"line": 1.2, "runs": [
        {"t": "进度风险　", "size": 12.5, "bold": True, "color": MUTED},
        {"t": "12 周计划预留 W11–W12 缓冲；W6 未达最小闭环就砍可选功能。", "size": 11.5, "color": INK2},
    ]})

    # ---------- slide 7: 创新 1/4 ----------
    set_para(get_shape(slides[6], "AutoShape 2").text_frame.paragraphs[0], [
        {"t": "三、特色与创新　1 / 4", "size": 11, "color": MUTED},
    ])

    # ---------- slide 8: 创新 2/4 ----------
    s8 = slides[7]
    set_para(get_shape(s8, "AutoShape 2").text_frame.paragraphs[0], [
        {"t": "三、特色与创新　2 / 4", "size": 11, "color": MUTED},
    ])
    set_para(get_shape(s8, "AutoShape 3").text_frame.paragraphs[0], [
        {"t": "创新点二 · 核心：用「事务 + 条件扣减」解决报名超发问题", "size": 26, "bold": True, "color": INK},
    ])
    good = get_shape(s8, "AutoShape 7")
    gps = good.text_frame.paragraphs
    set_para(gps[1], [
        {"t": "云侧仓颉服务在一个事务内完成「校验 + 条件扣减 + 写报名记录」。", "size": 12.5, "bold": True, "color": INK2},
    ], space_after=4)
    set_para(gps[2], [
        {"t": "UPDATE ... WHERE remain_count > 0 原子扣减；唯一索引防重复，失败整体回滚。", "size": 12, "color": INK2},
    ])
    rebuild_text_frame(get_shape(s8, "AutoShape 8"), [{"runs": [
        {"t": "技术支撑　", "size": 12, "bold": True, "color": BLUE},
        {"t": "数据库事务 ACID　·　行级锁 / 条件更新　·　仓颉强类型与错误处理　·　幂等键", "size": 12, "color": INK2},
    ]}])
    rebuild_text_frame(get_shape(s8, "AutoShape 9"), [{"runs": [
        {"t": "难点与贡献　", "size": 12.5, "bold": True, "color": ORANGE},
        {"t": "并发场景下的一致性是难点：既要保证不超报，又要保证用户体验。用数据库行锁 + 条件更新 + 幂等键，把正确性交给事务，把等待时间压到一次 UPDATE。",
         "size": 12.5, "color": INK2},
    ]}])
    rebuild_text_frame(get_shape(s8, "AutoShape 10"), [{"runs": [
        {"t": "差异化　", "size": 12, "bold": True, "color": BLUE},
        {"t": "多数校园报名小程序只做表单收集，不做并发控制与状态流转；本项目用仓颉服务实现完整业务闭环。",
         "size": 12, "color": INK2},
    ]}])

    # ---------- old slide 9: 形态 -> 创新 4/4 ----------
    s9 = slides[8]
    set_para(get_shape(s9, "AutoShape 2").text_frame.paragraphs[0], [
        {"t": "三、特色与创新　4 / 4", "size": 11, "color": MUTED},
    ])
    set_para(get_shape(s9, "AutoShape 3").text_frame.paragraphs[0], [
        {"t": "创新点四 · 形态：鸿蒙原生的全链路闭环", "size": 26, "bold": True, "color": INK},
    ])
    a_panel = get_shape(s9, "AutoShape 6")
    aps = a_panel.text_frame.paragraphs
    set_para(aps[1], [
        {"t": "仓颉云服务 + ArkTS 端侧 + 云数据库三层架构，端侧只走 HTTPS。", "size": 13, "bold": True, "color": INK2},
    ], space_after=4)
    set_para(aps[2], [
        {"t": "叠加鸿蒙生态空白 —— 已上架社团类应用无一做完整报名闭环。", "size": 12.5, "color": INK2},
    ])

    # ---------- old slide 10: 12 周分工 1/2 ----------
    s10 = slides[9]
    set_para(get_shape(s10, "AutoShape 2").text_frame.paragraphs[0], [
        {"t": "五、分工　1 / 2", "size": 11, "color": MUTED},
    ])
    set_para(get_shape(s10, "AutoShape 3").text_frame.paragraphs[0], [
        {"t": "三人 × 12 周：前 6 周打通最小闭环", "size": 26, "bold": True, "color": INK},
    ])
    set_para(get_shape(s10, "AutoShape 6").text_frame.paragraphs[0], [
        {"t": "接口第 2 周冻结；第 6 周产出「发布 → 报名 → 名单」最小闭环。", "size": 12.5, "bold": True, "color": ORANGE},
    ])
    for shp in list(s10.shapes):
        if shp.has_table:
            remove_shape(shp)
    weeks_1_6 = [
        ["周", "成员 A（前端 ArkTS / 交互）", "成员 B（仓颉业务内核 / API）", "成员 C（数据层 / 联调 / 上架）", "周末交付物"],
        ["1", "需求细化、页面原型、交互流程", "仓颉 1.0.5 + DevEco 26 环境验证，领域模型草案", "数据库选型、ER 图、云环境与账号", "原型 + 技术选型结论 + ER 图"],
        ["2", "设计 token、登录 / 首页骨架", "领域模型、状态机、Outcome/BizError、仓储接口", "DDL、索引、种子数据、内存仓储", "接口契约冻结"],
        ["3", "活动列表 / 详情、加载与空态", "登录、Token、角色权限、社团创建 / 审核", "SQL 适配器骨架、参数化查询、事务封装", "可登录并浏览活动"],
        ["4", "社团列表 / 详情、入社申请表单", "活动草稿 / 发布 / 状态机、权限守卫", "社团与活动表联调、迁移脚本 v1", "社团创建→审核→展示跑通"],
        ["5", "活动发布表单、我的页面", "报名校验链、幂等键、取消规则", "报名表 / 唯一索引、事务与回滚测试", "发布→报名→取消可演示"],
        ["6", "报名名单、筛选、导出入口", "名额条件扣减、并发 / 幂等测试", "并发压测、慢查询与索引修正", "最小闭环 + 压测报告"],
    ]
    add_table(s10, 0.72, 2.08, [0.55, 2.78, 3.02, 2.78, 2.76], weeks_1_6, row_height=0.575, body_size=10.0)
    rebuild_text_frame(get_shape(s10, "AutoShape 8"), [{"runs": [
        {"t": "里程碑　", "size": 11, "bold": True, "color": ORANGE},
        {"t": "W2 接口冻结　·　W6 最小闭环　·　W10 功能冻结　·　W12 提交审核", "size": 12, "bold": True, "color": INK},
    ]}])

    # ---------- new slide: 仓颉特色 ----------
    cj = content_slide(
        prs,
        "三、特色与创新　3 / 4",
        "创新点三 · 语言：仓颉不是胶水，而是业务内核",
        "把状态机、权限、并发这些最容易出错的逻辑，交给强类型语言在编译期管住。",
    )
    panels = [
        (0.72, 2.12, "类型即业务规则", BLUE,
         "enum ActivityState 把草稿 / 报名中 / 结束 / 下架写成封闭集合；match 穷举分支，新增状态时编译器逼你补全。"),
        (6.76, 2.12, "错误可枚举，不靠字符串", BLUE,
         "报名链路统一返回 Outcome<T, BizError>；名额满、重复报名、超时都是可测试的错误分支。"),
        (0.72, 3.82, "并发表达更贴近问题", ORANGE,
         "spawn 处理提醒、导出等旁路任务；名额扣减与报名记录写入同一事务边界，仓颉侧负责校验与幂等。"),
        (6.76, 3.82, "可复用的端侧校验内核", ORANGE,
         "核心校验库通过 C FFI（@C）导出，ArkTS 可在提交前做本地预校验；最终裁决仍在云侧。"),
    ]
    for px, py, heading, color, body in panels:
        add_panel(cj, px, py, 5.85, 1.55)
        add_panel_heading(cj, px + 0.18, py + 0.14, 5.50, heading, color, 14.5)
        add_text(cj, px + 0.18, py + 0.55, 5.50, 0.88,
                 [{"line": 1.12, "runs": [{"t": body, "size": 11.5, "color": INK2}]}])
    add_text(cj, 0.72, 5.56, 11.89, 0.30, [{"runs": [
        {"t": "落地位置　", "size": 10.5, "bold": True, "color": BLUE},
        {"t": "server/src/domain（状态机 / Outcome）· service（报名 / 权限 / 幂等）· repository（事务接口 + 内存实现）",
         "size": 10.5, "color": MUTED},
    ]}])
    add_takeaway(cj, "仓颉负责正确性，ArkTS 负责体验，数据库负责持久化 —— 边界清楚，才叫端云协同。")

    # ---------- new slide: 工程落地 ----------
    eng = content_slide(
        prs,
        "四、工程落地",
        "端云边界、数据库交互与上架审核",
        "把「谁访问数据库、事务在哪结束、审核要交什么」在开题阶段就说清楚。",
    )
    # left: boundary flow
    add_panel(eng, 0.72, 2.12, 5.95, 3.78)
    add_panel_heading(eng, 0.92, 2.24, 5.55, "端云边界：只留一条 HTTPS 通道", BLUE, 14.5)
    flow_boxes = [
        (2.62, "ArkTS 端侧", "UI / 状态 / 只读缓存｜不直连 DB、不持有密钥"),
        (3.62, "仓颉云侧服务", "鉴权 / 业务规则 / 事务 / 幂等"),
        (4.62, "云数据库", "PostgreSQL / GaussDB｜唯一数据源"),
    ]
    for fy, title, sub in flow_boxes:
        add_rect(eng, 0.92, fy, 5.55, 0.72, WHITE, LINE)
        add_text(eng, 1.04, fy + 0.08, 5.30, 0.58, [
            {"runs": [{"t": title + "　", "size": 12, "bold": True, "color": BLUE},
                      {"t": sub, "size": 10.5, "color": INK2}]},
        ], anchor=MSO_ANCHOR.MIDDLE)
    add_text(eng, 1.05, 3.37, 5.30, 0.22,
             [{"runs": [{"t": "↓　HTTPS + JSON · Bearer Token · Idempotency-Key", "size": 9.5, "color": ORANGE}]}])
    add_text(eng, 1.05, 4.37, 5.30, 0.22,
             [{"runs": [{"t": "↓　SQL · 参数化 · 仅私网", "size": 9.5, "color": ORANGE}]}])
    add_text(eng, 0.92, 5.43, 5.55, 0.36, [{"line": 1.1, "runs": [
        {"t": "端侧只发 HTTPS；写操作带幂等键；读缓存可离线，写请求必须在线。", "size": 10, "color": MUTED},
    ]}])
    # right top: DB interaction
    add_panel(eng, 6.87, 2.12, 5.74, 1.80)
    add_panel_heading(eng, 7.05, 2.22, 5.40, "数据库交互实现层", BLUE, 14)
    add_text(eng, 7.05, 2.58, 5.40, 1.24, [
        {"space_after": 2, "runs": [{"t": "· Repository 接口 + SQL 适配器；service 定义事务边界", "size": 9.8, "color": INK2}]},
        {"space_after": 2, "runs": [{"t": "· 名额：UPDATE ... WHERE remain_count > 0，以 rowcount 为准", "size": 9.8, "color": INK2}]},
        {"space_after": 2, "runs": [{"t": "· 防重：唯一索引 (activity_id, user_id) WHERE is_cancel = false", "size": 9.8, "color": INK2}]},
        {"space_after": 2, "runs": [{"t": "· 取消：先活动行、后报名行，统一锁顺序避免死锁", "size": 9.8, "color": INK2}]},
        {"runs": [{"t": "· SQL 全部参数化；迁移脚本版本化；端侧零 SQL", "size": 9.8, "color": INK2}]},
    ])
    # right bottom: app store review
    add_panel(eng, 6.87, 4.08, 5.74, 1.82)
    add_panel_heading(eng, 7.05, 4.18, 5.40, "上架审核：无 AI，路径更短", ORANGE, 14)
    add_text(eng, 7.05, 4.54, 5.40, 1.26, [
        {"space_after": 2, "runs": [{"t": "· 不涉及生成式 AI / 深度合成 → 无需算法备案与深度合成标识", "size": 9.8, "color": INK2}]},
        {"space_after": 2, "runs": [{"t": "· 仍需隐私政策、权限最小化（仅网络）、个人信息清单、账号注销", "size": 9.8, "color": INK2}]},
        {"space_after": 2, "runs": [{"t": "· 不采集通讯录 / 位置 / 相册；通知权限在使用时申请", "size": 9.8, "color": INK2}]},
        {"space_after": 2, "runs": [{"t": "· 提供学生 / 负责人 / 管理员三套审核账号与审核说明", "size": 9.8, "color": INK2}]},
        {"runs": [{"t": "· 社团 / 活动文本人工审核 + 举报入口；先内测再正式提交", "size": 9.8, "color": INK2}]},
    ])
    add_takeaway(eng, "端侧不碰数据库，云侧不信任端侧；审核材料从第 1 周就开始攒，而不是最后一周补。")

    # ---------- new slide: 12 周分工 2/2 ----------
    w2 = content_slide(
        prs,
        "五、分工　2 / 2",
        "三人 × 12 周：后 6 周补齐体验与上架",
        "W10 功能冻结；W12 提交 AppGallery，留出至少 1 周审核缓冲。",
    )
    weeks_7_12 = [
        ["周", "成员 A（前端 ArkTS / 交互）", "成员 B（仓颉业务内核 / API）", "成员 C（数据层 / 联调 / 上架）", "周末交付物"],
        ["7", "消息中心、未读红点、通知权限", "消息服务、定时提醒任务", "消息表 / 投递记录、重试机制", "报名结果与活动提醒全链路"],
        ["8", "统计看板、图表组件", "统计聚合接口、权限过滤", "聚合 SQL、索引优化、性能基线", "社团 / 全校统计可看"],
        ["9", "管理员后台、审核 / 下架交互", "管理员审核 / 下架、审计日志", "审计表、数据保留与备份策略", "三方角色后台齐备"],
        ["10", "UI 打磨、弱网 / 异常态、无障碍", "契约测试、错误码统一、边界用例", "安全检查（越权 / 注入 / 密钥）、恢复演练", "功能冻结 + 缺陷清单"],
        ["11", "演示脚本、截图、答辩材料", "性能优化、代码冻结、文档", "生产部署、监控告警、审核账号", "Release Candidate + 上架材料"],
        ["12", "答辩演示、用户反馈整理", "最终回归、版本号与更新说明", "提交 AppGallery、跟进审核问题", "上架提交 + 答辩"],
    ]
    add_table(w2, 0.72, 2.08, [0.55, 2.78, 3.02, 2.78, 2.76], weeks_7_12, row_height=0.575, body_size=10.0)
    add_rect(w2, 0.72, 6.20, 0.90, 0.05, ORANGE)
    add_text(w2, 0.72, 6.40, 11.89, 0.42, [{"runs": [
        {"t": "贯穿机制　", "size": 11, "bold": True, "color": BLUE},
        {"t": "每周一次例会 + 代码互审；A / B / C 按技术栈分工，接口契约变更必须走 PR。", "size": 11, "color": MUTED},
    ]}])

    # ---------- reorder ----------
    desired = [0, 1, 2, 3, 4, 5, 6, 7, 11, 8, 12, 9, 13, 10]
    sldIdLst = prs.slides._sldIdLst
    elements = list(sldIdLst)
    for el in elements:
        sldIdLst.remove(el)
    for i in desired:
        sldIdLst.append(elements[i])

    # ---------- footers ----------
    for index, slide in enumerate(prs.slides):
        if index == 0 or index == len(prs.slides) - 1:
            continue
        rebuild_footer(slide, index + 1)

    prs.save(dst)
    print("saved", dst, "slides", len(prs.slides))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
