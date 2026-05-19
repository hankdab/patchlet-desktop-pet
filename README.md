# 小补丁桌面宠物

这是一个 Windows / macOS 桌面宠物项目。小补丁会在桌面边缘自由巡逻，支持拖拽文档或选择文档让它读取内容。当前版本统一为单形态桌宠，不再按圈数切换进化阶段。

## 分支说明

- 分支：`codex/hatch-pet-skill-desktop-pet`
- 技能来源：Codex `hatch-pet` skill
- 图像生成：`imagegen` skill
- 发布方式：GitHub plugin / `gh` CLI

## 功能

- 总在最前、透明背景的桌面宠物窗口。
- 沿桌面边缘巡逻，向右移动播放右跑动画，向左移动播放左跑动画。
- Native macOS 版本会贴着屏幕四边巡逻，并在左右边缘使用上下方向的专用动画。
- 坐着或等待时不移动。
- 跑动时半透明，鼠标靠近后变为不透明。
- 拖入 `.txt`、`.md`、`.json`、`.csv`、`.docx`、`.pdf`、`.xlsx`、`.xlsm` 后自动读取并生成摘要报告。
- macOS 可通过右键菜单选择文件；如果本机 `tkinterdnd2`/`tkdnd` 可用，也支持拖入文件。
- Native macOS 版本可接收任务完成信号，收到后播放系统喵声提示。

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

### Native macOS app

仓库还包含一个不依赖 Python/Tk 的原生 macOS 版本，使用 Swift/AppKit 构建：

```bash
cd desktop_pet
./build-native-macos-app.sh
open dist/PatchletNative.app
```

Native 版本会把单形态动画资源和 `PatchletPaw.icns` 图标复制进 `.app` 包，窗口为无边框透明浮窗。它目前专注于桌面边缘巡逻、方向动画和任务完成提示，不包含 Python/Tk 版本的文档摘要流程。

### 任务完成喵声

Native macOS app 每秒检查一次：

```text
~/Library/Application Support/Patchlet/task-complete.signal
```

当这个文件的修改时间更新时，小补丁会播放 macOS 系统音效 `Purr.aiff`；如果系统找不到该音效，会回退到 `Purr`、`Glass` 或系统 beep。可以用随附脚本触发：

```bash
cd desktop_pet
./signal-task-complete.sh
```

也可以手动触发：

```bash
mkdir -p "$HOME/Library/Application Support/Patchlet"
touch "$HOME/Library/Application Support/Patchlet/task-complete.signal"
```

这个信号文件适合接在外部任务、脚本或自动化流程的最后一步，用来告诉桌宠“任务做完了”。

## 操作

- 左键拖动宠物可以移动它。
- 把文档文件拖到宠物身上，它会读取并弹出摘要。
- 右键宠物可暂停/继续、选择文件、打开上一份报告或退出。
- macOS 也支持 Control + 左键打开菜单。

## macOS 说明

macOS 版本复用同一份 Tk/Python 程序。窗口会尽量保持透明、置顶和无边框；由于 Tk 在 macOS 上不总是支持 Windows 风格的色键透明，部分系统可能会退回为整体半透明窗口。拖拽文件依赖 `tkinterdnd2` 附带的原生 `tkdnd`，不可用时仍可通过右键菜单选择文件。

原生 Swift/AppKit 版本使用独立入口 `desktop_pet/macos/PatchletNative.swift`，可通过 `build-native-macos-app.sh` 直接编译成 `dist/PatchletNative.app`。它会优先从 `.app` 包内的 `Contents/Resources/assets/` 读取动画资源；如果直接从构建产物运行，也会尝试读取当前目录下的 `assets/`。

## 边缘巡逻与形态

小补丁现在只保留一套形态，使用 `spritesheet.webp` 作为基础动作图集。Python/Tk 版本会在桌面边缘巡逻：底边向左跑、左边和右边沿边缘移动、顶边向右跑，回到底边后只累计圈数，不再触发进化。

Native macOS 版本同样是单形态，会围绕可见屏幕边缘巡逻，在四边之间顺时针或逆时针移动，偶尔原地休息，并随机切换巡逻方向。检测到多个显示屏时，如果当前水平移动方向通向相邻显示屏，它会从当前屏幕边缘直接进入相邻屏幕的对应边缘继续移动，不必等跑完整圈。左右边缘使用 `patchlet-edge-directions.png` 中的上下移动帧；如果该资源缺失，会退回到基础帧。

## 运动状态清单

Native macOS 版本当前覆盖这些运动和反馈状态：

- `idle`：原地待机。
- `running-left` / `running-right`：沿底边或顶边左右移动。
- `left-edge up` / `left-edge down`：沿左边缘上下移动。
- `right-edge up` / `right-edge down`：沿右边缘上下移动。
- `jumping`：跳跃反馈。
- `waiting` / `review` / `failed`：等待、审阅和失败反馈。
- `task completion meow`：收到任务完成信号后播放系统喵声。
- 多显示屏连续跨屏：沿水平方向跑到相邻显示屏时，直接从一块屏幕进入另一块屏幕继续移动。

## 项目结构

```text
desktop_pet/
  main.py                 # 桌面宠物主程序
  run-desktop-pet.ps1     # Windows 启动脚本
  run-desktop-pet.command # macOS 启动脚本
  build-macos-app.sh      # macOS .app 构建脚本
  build-native-macos-app.sh # Native macOS .app 构建脚本
  signal-task-complete.sh # 触发 Native macOS 任务完成喵声
  requirements.txt        # Python 依赖
  macos/
    PatchletNative.swift  # Swift/AppKit 原生桌宠入口
    icons/
      PatchletPaw.icns    # Native macOS App 图标
  scripts/
    generate-edge-directions.py # 从基础跑步帧生成边缘方向动画资源
  assets/
    spritesheet.webp          # 单形态基础图集
    patchlet-edge-directions.png # Native 单形态边缘上下方向动画，每行 16 帧
```

文档摘要报告会写入 `desktop_pet/reports/`，该目录不会提交到仓库。

## 资源文件说明

- `assets/spritesheet.webp`：单形态小补丁图集，按 192 x 208 单元格切帧；包含待机、左右跑、挥手、跳跃、失败、阅读等状态。
- `assets/patchlet-edge-directions.png`：Native macOS 单形态版本的边缘方向图集，按 208 x 192 单元格切帧；4 行分别对应右边缘向下、右边缘向上、左边缘向下、左边缘向上，每行动作 16 帧。
- `macos/icons/PatchletPaw.icns`：Native macOS `.app` 图标，由构建脚本复制到 `Contents/Resources/`。
