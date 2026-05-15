# 小补丁桌面宠物

这是一个 Windows 桌面宠物项目。小补丁会在桌面边缘自由巡逻，支持拖拽文档到它身上读取内容，并会在绕桌面跑完指定圈数后自动进化。

## 分支说明

- 分支：`codex/hatch-pet-skill-desktop-pet`
- 技能来源：Codex `hatch-pet` skill
- 图像生成：`imagegen` skill
- 发布方式：GitHub plugin / `gh` CLI

## 功能

- 总在最前、透明背景的桌面宠物窗口。
- 沿桌面边缘巡逻，向右移动播放右跑动画，向左移动播放左跑动画。
- 坐着或等待时不移动。
- 跑动时半透明，鼠标靠近后变为不透明。
- 拖入 `.txt`、`.md`、`.json`、`.csv`、`.docx`、`.pdf`、`.xlsx`、`.xlsm` 后自动读取并生成摘要报告。
- 跑完第 1 圈进化为带翅膀和电光的进化形态。
- 跑完第 2 圈进化为身体更长、爪子更锋利、翅膀更大的终极形态。

## 运行方式

需要 Windows 和 Python 3.12 或兼容版本。

```powershell
cd desktop_pet
.\run-desktop-pet.ps1
```

脚本会安装 `requirements.txt` 中的依赖，然后启动桌面宠物。

## 操作

- 左键拖动宠物可以移动它。
- 把文档文件拖到宠物身上，它会读取并弹出摘要。
- 右键宠物可暂停/继续、选择文件、打开上一份报告或退出。

## 项目结构

```text
desktop_pet/
  main.py                 # 桌面宠物主程序
  run-desktop-pet.ps1     # Windows 启动脚本
  requirements.txt        # Python 依赖
  assets/
    spritesheet.webp          # 基础形态
    patchlet-evolved.webp     # 进化形态
    patchlet-ultimate.webp    # 终极形态
```

文档摘要报告会写入 `desktop_pet/reports/`，该目录不会提交到仓库。
