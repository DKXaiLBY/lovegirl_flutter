# 项目路径英文化 — 执行手册（2026-09-25）

## 背景

项目物理路径 `D:\项目\个人项目\lovegirl` 含中文，导致 Flutter 构建工具链（impellerc 写 shader）失败，构建被迫依赖 `D:\lovegirl_build` junction。用户拍板把一级、二级路径改为英文：

```
D:\项目\个人项目\lovegirl  →  D:\Projects\Personal\lovegirl
```

## 为什么不能让 ZCode 代做

ZCode 窗口进程的工作目录绑定在项目内，进程无法改名自己（或其祖先）的工作目录——会报"访问被拒绝"。已实测排除 adb/dart/Explorer 等其他占用者。**必须关闭所有 ZCode 窗口后由用户在本机终端执行。**

## 执行步骤

1. **关闭所有 ZCode 窗口**（这是解除目录锁的唯一方法）
2. 打开 PowerShell（Win 键 → 输入 powershell → 回车，不需要管理员）
3. 粘贴以下整块并回车：

```powershell
cd D:\
if (Test-Path 'D:\Projects') { Write-Output '[X] D:\Projects 已存在，中止'; exit 1 }
Rename-Item -LiteralPath 'D:\项目' -NewName 'Projects'
Write-Output '[OK] D:\项目 -> D:\Projects'
Rename-Item -LiteralPath 'D:\Projects\个人项目' -NewName 'Personal'
Write-Output '[OK] D:\Projects\个人项目 -> D:\Projects\Personal'
if (Test-Path 'D:\lovegirl_build') { cmd /c rmdir "D:\lovegirl_build" }
cmd /c mklink /J "D:\lovegirl_build" "D:\Projects\Personal\lovegirl"
Write-Output '[OK] junction 已重挂'
if (Test-Path 'D:\Projects\Personal\lovegirl\pubspec.yaml') { Write-Output '=== 完成！新地址: D:\Projects\Personal\lovegirl ===' } else { Write-Output '[X] 验证失败' }
```

4. 重新打开 ZCode，选择工作目录 `D:\Projects\Personal\lovegirl`

## 附带影响（已核实，无需担心）

- `D:\项目\学校项目` 只是跟着搬到 `D:\Projects\学校项目`（目录名不变，里面文件不动）；如也想改名，方法相同
- git 仓库不含绝对路径，改名后照常工作
- `local.properties` 只存 SDK 路径，与项目路径无关
- `publish.py` 的 PROJECT 取脚本自身位置，自适应
- `build_v331.bat` 用 `D:\lovegirl_build`，junction 重挂后照常
- 改名后首次 `flutter analyze` 前先跑一次 `flutter pub get`（.dart_tool 里的绝对路径失效）
