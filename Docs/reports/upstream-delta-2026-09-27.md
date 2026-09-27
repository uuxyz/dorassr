# 当前分支相对上游的修改清单（2026-09-27）

## 比较基准

- 上游：本地远端跟踪分支 `upstream/main`，`8755cef10`（2026-09-26）。本次没有联网更新该引用。
- 当前：`main`，`5aeaf6ce6`（2026-09-27）。`upstream/main` 是当前提交的祖先；当前多 81 个提交，上游没有本地尚未包含的提交。
- 本报告的已提交差异采用 `git diff --no-renames upstream/main...HEAD`。不启用重命名识别，方便稳定地列出删除、增加和修改路径；因此迁移文件会分别记为删除与增加。
- `origin/main` 是另一条远端分支，当前与它的分叉为对方独有 91 个、本地独有 89 个提交。它不是本报告的比较基准。

## 规模与完整索引

| 范围 | 路径变更 | 增加 | 修改 | 删除 | 说明 |
| --- | ---: | ---: | ---: | ---: | --- |
| `Source/3rdParty` | 3,641 | 1,715 | 488 | 1,438 | 上游组件升级和 SDL2→SDL3 切换；占全部路径变更约 96% |
| 生成的着色器头 `Source/Shader/**/*.bin.h` | 42 | 0 | 42 | 0 | 与 bgfx/shaderc 升级配套重新生成 |
| 旧 iOS/macOS Xcode 项目 | 4 | 0 | 0 | 4 | 改用 CMake 生成项目 |
| 其余项目源码、构建、工具、CI | 112 | 25 | 85 | 2 | 应重点人工审阅 |
| **合计** | **3,799** | **1,740** | **615** | **1,444** | 路径级计数，重命名按删加计 |

完整路径清单见 [upstream-delta-files-2026-09-27.tsv](upstream-delta-files-2026-09-27.tsv)，每行是 Git 状态（`A/M/D`）和路径。81 个提交按时间顺序列在 [upstream-delta-commits-2026-09-27.tsv](upstream-delta-commits-2026-09-27.tsv)。这两个清单只记录已提交差异，不包括下文的工作区改动，也不包括本报告文件。

### 第三方源码

| 目录 | 路径变更 | 内容 |
| --- | ---: | --- |
| `SDL2` | 1,216 | 删除整棵原有源码树；此前先将 Dora 分支更新至 SDL 2.32.0，随后迁至 SDL3 |
| `SDL3` | 1,478 | 新增 SDL 3.4.14 源码树 |
| `bgfx` | 799 | 升级 API 129→161 及后续上游同步，调整内嵌 shaderc 集成 |
| `bx` | 103 | 升级至较新的上游版本 |
| `bimg` | 20 | 升级至较新的上游版本 |
| `shaderc` | 13 | 从 bgfx 工具目录拆出并更新编译器源码 |
| 其余第三方目录 | 12 | Effekseer、Love、Other、Wa、font、nfd、soloud、theora、yarnflow 的适配或元数据修改 |

## 项目自身的主要修改

1. **渲染边界与 bgfx 适配。** 新增 `RenderSurface` 和 `RenderCompat`，把渲染设备生命周期、视图及纹理相关调用从应用主流程拆出；调整 `Director`、`RenderTarget`、`View`、节点及缓存层；新增 `DoraShaderc`，把运行时着色器编译接到升级后的 bgfx/shaderc。主要提交从 `99dcbf428`、`3d8be993b`、`4896bc338` 到 `cbc61a53f`。
2. **SDL3 迁移。** 引擎事件、输入、控制器、触摸、窗口、文件 IO、音频和各平台入口改用 SDL3 API；触摸多手势在 SDL3 finger 事件上重建。主线从 `98825a028` 到 `53846e2b9`，后续有平台、音频、输入与光标修复。
3. **构建系统与平台工程。** Linux、Windows 新增 xmake 应用目标及源文件列表；Apple 改用共享 CMake 定义并生成 Xcode 工程；Android、Web、Emscripten、iOS、macOS 的依赖和链接规则同步调整；新增 SDL3 构建脚本、着色器再生成脚本、Nix 包装和版本注入。对应 `Projects`、`Tools`、`packaging` 的路径详见清单。
4. **CI 与检查。** 七个 GitHub Actions 工作流修改了平台依赖、缓存、触发条件及构建命令；新增渲染边界检查脚本，触摸输入检查脚本随 SDL3 更新。
5. **近期运行时修复。** 包括 SDL3/SoLoud 错误处理、GLSL 330 请求、运行时 shader include 查找、ImGui 光标可见性以及单帧 delta time 上限与停顿诊断；这些位于最后几个提交。

## 当前尚未提交的改动

这部分独立于上述 81 个提交，保留原样：12 个已修改文件（137 行增加、48 行删除）和 1 个未跟踪脚本。

| 主题 | 文件 | 当前内容 |
| --- | --- | --- |
| 构建与运行时 shader | `Projects/Linux/CMakeLists.txt`、`Projects/Web/CMakeLists.txt` | 嵌入 bgfx shader 头；为 Web glslang 启用必要宏与头文件路径 |
| 输入和视图 | `Source/Basic/Application.cpp`、`Source/Input/TouchDispather.h`、`Source/Node/View3D.cpp` | 丢弃停顿后过期的指针事件、增加手势状态字段、给 Surface3D 视图设置投影矩阵 |
| bgfx 指标 | `Source/Basic/Director.cpp`、`Source/GUI/ImGuiDora.cpp` | 使用新的临时缓冲区容量字段 |
| Rust 3D/bgfx ABI | `Source/Rust/src/bgfx_rs/bgfx_sys/ffi.rs`、`Source/Rust/src/bgfx_rs/static_lib.rs`、`Source/Rust/src/dora_3d/{material,shader,texture}.rs` | 更新枚举、顶点布局和 C 接口参数；移除 simple PBR 路径 |
| 未跟踪检查脚本 | `Tools/build-scripts/check_bgfx_3d_abi.mjs` | 对照 bgfx C 头检查 Rust 3D 绑定中的枚举、结构与函数参数数量 |

## 建议的整理顺序

1. 先决定本地的 `upstream/main` 是否需要刷新，再固定新的比较基准；本报告对应的是上面列出的确切提交。
2. 将当前工作区改动作为独立的待完成批次审阅，尤其是 bgfx Rust ABI 和输入事件过滤逻辑；不要把它们混入已提交的第三方升级统计。
3. 若要缩小与上游的长期差异，优先把第三方源码升级、SDL3 迁移、渲染边界改造、平台构建修改分别维护为可识别的变更组。`SDL2` 删除与 `SDL3` 增加应作为同一迁移理解。
4. 审阅时先看本报告中的 112 个项目自有路径，再按需要深入第三方树和 42 个生成头文件。完整逐文件状态可从 TSV 复核。

## 复核命令

```sh
git rev-list --left-right --count upstream/main...HEAD
git log --reverse --oneline upstream/main..HEAD
git diff --no-renames --name-status upstream/main...HEAD
git status --short
```
