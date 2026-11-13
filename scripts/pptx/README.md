# 开题 PPT 修改脚本

## 用途

按老师反馈重新生成开题 PPT：

- 新增「仓颉语言特色」页
- 新增「端云边界 / 数据库交互 / 上架审核」页
- 把 8 周分工细化成 12 周（两页）
- 统一页脚、色板、字体

## 用法

```bash
python scripts/pptx/modify_opening_ppt.py \
  "校园活动与社团管理_原版备份.pptx" \
  "校园活动与社团管理.pptx"
```

依赖：`python-pptx`、`lxml`。

```bash
pip install python-pptx lxml
```

## 注意

- 脚本按**原始 PPT 的 shape 名称**定位（如 `AutoShape 8`），
  只适用于 `校园活动与社团管理_原版备份.pptx` 这一版；
  如果原始 PPT 结构变了，需要同步改 shape 名称。
- 生成后建议用 PowerPoint 打开检查一遍，或导出 PNG：
  ```powershell
  $ppt = New-Object -ComObject PowerPoint.Application
  $pres = $ppt.Presentations.Open("...\校园活动与社团管理.pptx", $true, $false, $false)
  $pres.Export("...\render", "PNG", 1600, 900)
  $pres.Close(); $ppt.Quit()
  ```
- 原版备份不要删；答辩时如果老师问「原来是什么样」，可以对照。
