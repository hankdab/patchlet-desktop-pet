# 小补丁桌面宠物

这是小补丁桌面宠物的可运行程序目录。该项目由 Codex `hatch-pet` skill 孵化，动画帧由 `imagegen` skill 生成。

## 功能

- 透明、总在最前的桌面宠物窗口。
- 沿桌面边缘巡逻，左右移动会播放对应方向的跑步动画。
- 坐着或等待时保持原地不动。
- 跑动时半透明，鼠标靠近后恢复不透明。
- 支持拖入文档文件并读取摘要；macOS 上拖拽不可用时可用右键菜单选择文件。
- 绕桌面跑完一圈进化，再跑完一圈进入终极进化。

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

## 支持的文件

`.txt`、`.md`、`.json`、`.csv`、`.docx`、`.pdf`、`.xlsx`、`.xlsm`

摘要报告会写入 `reports/`，该目录默认不提交。
