# 小补丁桌面宠物

这是一个 Windows / macOS 桌面宠物项目。小补丁会在桌面边缘自由巡逻，支持拖拽文档或选择文档让它读取内容，并会在绕桌面跑完指定圈数后自动进化。

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
- macOS 可通过右键菜单选择文件；如果本机 `tkinterdnd2`/`tkdnd` 可用，也支持拖入文件。
- 跑完第 1 圈进化为带翅膀和电光的进化形态。
- 跑完第 2 圈进化为身体更长、爪子更锋利、翅膀更大的终极形态。

## 运行方式

需要 Python 3.10+。Windows 使用 PowerShell 启动：

```powershell
cd desktop_pet
.\run-desktop-pet.ps1
```

macOS 使用双击或终端启动：

```bash
cd desktop_pet
./run-desktop-pet.command
```

脚本会创建本地虚拟环境、安装 `requirements.txt` 中的依赖，然后启动桌面宠物。

如果想构建 `.app`，在 macOS 上运行：

```bash
cd desktop_pet
./build-macos-app.sh
open dist/Patchlet.app
```

## 操作

- 左键拖动宠物可以移动它。
- 把文档文件拖到宠物身上，它会读取并弹出摘要。
- 右键宠物可暂停/继续、选择文件、打开上一份报告或退出。
- macOS 也支持 Control + 左键打开菜单。

## macOS 说明

macOS 版本复用同一份 Tk/Python 程序。窗口会尽量保持透明、置顶和无边框；由于 Tk 在 macOS 上不总是支持 Windows 风格的色键透明，部分系统可能会退回为整体半透明窗口。拖拽文件依赖 `tkinterdnd2` 附带的原生 `tkdnd`，不可用时仍可通过右键菜单选择文件。

## 项目结构

```text
desktop_pet/
  main.py                 # 桌面宠物主程序
  run-desktop-pet.ps1     # Windows 启动脚本
  run-desktop-pet.command # macOS 启动脚本
  build-macos-app.sh      # macOS .app 构建脚本
  requirements.txt        # Python 依赖
  assets/
    spritesheet.webp          # 基础形态
    patchlet-evolved.webp     # 进化形态
    patchlet-ultimate.webp    # 终极形态
```

文档摘要报告会写入 `desktop_pet/reports/`，该目录不会提交到仓库。
