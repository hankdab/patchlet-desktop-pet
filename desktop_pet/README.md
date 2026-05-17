# 小补丁桌面宠物

这是小补丁桌面宠物的可运行程序目录。该项目由 Codex `hatch-pet` skill 孵化，动画帧由 `imagegen` skill 生成。

## 功能

- 透明、总在最前的桌面宠物窗口。
- 沿桌面边缘巡逻，左右移动会播放对应方向的跑步动画。
- Native macOS 版本会沿屏幕四边移动，并在左右边缘使用上下方向的专用动画。
- 坐着或等待时保持原地不动。
- 跑动时半透明，鼠标靠近后恢复不透明。
- 支持拖入文档文件并读取摘要；macOS 上拖拽不可用时可用右键菜单选择文件。
- Native macOS 版本支持任务完成信号，收到后播放系统喵声。
- 当前版本统一为单形态桌宠，不再按圈数切换进化阶段。

## 运行

Windows:

```powershell
.\run-desktop-pet.ps1
```

macOS:

```bash
./run-desktop-pet.command
```

启动脚本会安装依赖并运行 `main.py`。macOS 构建 `.app` 可运行：

```bash
./build-macos-app.sh
open dist/Patchlet.app
```

Native macOS app:

```bash
./build-native-macos-app.sh
open dist/PatchletNative.app
```

Native 版本使用 Swift/AppKit 编译，运行时不需要 Python 虚拟环境。它当前负责无边框浮窗、单形态边缘巡逻、方向动画和任务完成喵声；文档拖拽摘要仍由 Python/Tk 版本提供。

## 任务完成喵声

Native macOS app 会监听这个信号文件的修改时间：

```text
~/Library/Application Support/Patchlet/task-complete.signal
```

任务结束时运行：

```bash
./signal-task-complete.sh
```

脚本会创建 `~/Library/Application Support/Patchlet/`，更新 `task-complete.signal`，正在运行的 Native app 检测到更新后会播放系统 `Purr.aiff`。如果该音效不可用，会回退到系统内置音效或 beep。

## 边缘巡逻与形态

Python/Tk 版本使用屏幕边缘作为巡逻路径：底边、左边、顶边、右边依次移动，回到底边算完成一圈。完成一圈后只累计圈数，不再切换形态。

Native macOS 版本也是单形态版本，会贴着可见屏幕区域巡逻，支持顺时针和逆时针方向，完成一圈后可能短暂停留，并可能随机调头。检测到多个显示屏时，如果当前水平移动方向通向相邻显示屏，它会从当前屏幕边缘直接进入相邻屏幕的对应边缘继续移动，不必等跑完整圈。它使用 `patchlet-edge-directions.png` 提供左右边缘的上/下移动帧，资源缺失时会回退到基础帧。

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

## 支持的文件

`.txt`、`.md`、`.json`、`.csv`、`.docx`、`.pdf`、`.xlsx`、`.xlsm`

摘要报告会写入 `reports/`，该目录默认不提交。

## 资源文件

```text
assets/
  spritesheet.webp              # 单形态基础图集，192 x 208 单元格
  patchlet-edge-directions.png  # Native 单形态左右边缘上下移动图集，208 x 192 单元格
macos/
  PatchletNative.swift          # Native macOS App 入口
  icons/PatchletPaw.icns        # Native macOS App 图标
scripts/
  generate-edge-directions.py   # 生成边缘方向图集的辅助脚本
```

Python/Tk 版本优先读取打包资源，其次读取源码目录和 `~/.codex/pets/` 下的孵化结果。Native macOS 构建会把单形态动画资源和 `PatchletPaw.icns` 复制进 `dist/PatchletNative.app/Contents/Resources/`。
