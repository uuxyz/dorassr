# bgfx 整合说明（解耦版）

Dora-SSR 使用 bgfx/bx/bimg 的方式是 **vendored + 零补丁政策**：

- `Source/3rdParty/{bgfx,bx,bimg}` = 上游快照 + main 分支上的普通修改 commit。
  不使用补丁文件、不使用 submodule、上游历史不进入本仓库。
- 本地修改的基准与来源记录在**各库目录内的 `UPSTREAM` 文件**中
  （repository / branch / tree / commit），元数据跟着目录走，自描述、无感。
  升级脚本以此作为三方合并的 merge base，并从同一文件读取仓库地址。
- Dora 与渲染设备的边界由三个机制保证（见下文"渲染边界架构"）：
  1. `Source/Render/RenderSurface` —— 初始化/交换链生命周期的唯一入口；
  2. `Source/Render/RenderCompat.h` —— 引擎全局唯一可见的渲染设备常量头；
  3. `Tools/build-scripts/check_render_boundary.sh` —— 边界的机器检查（可挂 CI）。
- Dora 自有代码全部在这棵树之外：
  - `Source/3rdParty/shaderc/` —— bgfx shaderc 工具的 **fork**（含 Dora 的运行时
    编译 API 改造与 Web bypass）。上游 bgfx 库构建不使用 tools/shaderc，因此
    fork 独立维护；升级 bgfx 后如需同步，与新上游 tools/shaderc 做一次 diff。
  - `Source/Shader/DoraShaderc/` —— 运行时着色器编译 C API 包装（编入 shaderc-lib），
    `generated/` 内是 xmake `utils.bin2c` 生成的嵌入式 shader 头。
  - `Tools/bgfx/xmake.lua` —— bgfx/bx/bimg/shaderc 的构建脚本（不放在上游树内）。
- 渲染后端、framebuffer 上限等配置全部通过构建参数注入（不再改上游 config.h）：
  见 `Tools/bgfx/xmake.lua` 的 `add_bgfx_renderer_config`。
- 构建产物输出到 `Source/3rdParty/bgfx/build/<plat>/<arch>/<mode>/`（gitignore），
  各平台工程（CMake / vcxproj / xcodeproj）引用该路径。

## 渲染边界架构

bgfx 的 API 稳定性不均匀：每帧绘制路径（encoder/view/texture/program）多年未变，
而初始化与窗口生命周期（init/platformData/swapChain/reset）几乎每个大版本都有
破坏性变更。因此边界按稳定性划分：

| 层 | 文件 | 允许包含 bgfx 头 |
| --- | --- | --- |
| 全引擎公共层 | `Const/Header.h`（PCH）及所引头 | ❌ 仅 `bx/platform.h`（平台宏）；全局常量走 `RenderCompat.h` |
| 生命周期域 | `Source/Render/RenderSurface.{h,cpp}` | ✅（.cpp；.h 对外零渲染类型） |
| 渲染域/适配器 | `Source/{Render,Shader,Cache,Node,Effect,GUI,Love,Lua}`、`Basic/Director.cpp`、3rdParty 渲染适配库 | ✅ 显式 `#include <bgfx/bgfx.h>`（不得依赖 PCH 泄漏） |
| 其余引擎代码 | Basic（除 Director）/Support/Animation/Audio/... | ❌ 编译器不可见 bgfx |

违反边界的改动会被 `check_render_boundary.sh` 拦截。若某功能确实需要跨边界，
按以下三种方式之一落地，而不是改上游树：

1. **上游 PR**（bug 或通用 feature，如 WebGL EAC 扩展路由 #3980）；
2. **引擎侧实现**（如 readTexture 需求 → 引擎走 blit-to-staging）；
3. **Dora 侧包装组件**（如 shaderc fork 模式）。

## 升级上游

```bash
# 仓库地址自动从各库的 UPSTREAM 文件读取；也支持 --dir 指向解压的 tarball
./update-upstream.sh bgfx --fetch <ref>   # 例: <ref> = master 或某个 tag
./update-upstream.sh bimg --fetch <ref>
./update-upstream.sh bx   --fetch <ref>
```

脚本对 `BASE（上次同步的上游树）/ OURS（当前子树）/ THEIRS（新上游树）` 做
`git merge-tree` 三方合并：

- 无冲突 → 直接写回子树并更新 `bases`，重编译即可。
- 有冲突 → 冲突标记写在真实文件里（同 rebase 体验），逐个解决后
  `git add -A && git commit`，`bases` 随之更新。
- 修复面预期：`RenderSurface.cpp`（初始化/交换链模型）、`RenderCompat.h`
  （改名）与渲染白名单内少量编译错误，引擎其余部分不受影响。

注意：`.mm` 等 Apple 平台变体文件不受 Linux 构建覆盖，改动后先跑
本机检查或交由 CI 验证。

## 当前对上游的本地修改清单（基准: bgfx API 129, 导入 commit 0836aa1d1）

查看方式: `git diff <上游树>:Source/3rdParty/<lib> HEAD:Source/3rdParty/<lib>`

## 补丁清单（基准: bgfx API 129, Dora-SSR 0836aa1d1 导入）

### bgfx / bx / bimg 仍保留的修改主题

| 主题 | 涉及 | 上游化状态 |
| --- | --- | --- |
| EAC 纹理格式（bgfx/bimg 全套） | 公开枚举、各后端能力表、WebGL 扩展路由、bimg 编解码 | EAC 格式已进上游（#3487），EACR11 命名迁移待升级时处理；WebGL 路由已 PR #3980 |
| GL 后端修复（renderer_gl/glimports） | uniform 精度统一、链接失败日志、新增 GL 入口 | 精度问题上游已重构消失；其余待评估 |
| 平台修复（bgfx_p/EGL/D3D/Metal） | Android 恢复前台竞态、readTexture 放宽、KMSDRM 外部 context、Metal EAC 门控 | 竞态与外部 context 上游已重构解决；readTexture 上游立场明确拒绝，引擎侧改走 blit |
| glsl-optimizer/fcpp MSVC 构建修复 | 3rdparty 快照内的 cast 修复 | 上游不收 3rdparty 改动，长期保留 |
| bx Windows SDK 版本推导 | `<sdkddkver.h>` 替代手工 WINVER | 待开 issue 讨论 |
| `amalgamated.cpp` 的构建排除 | Web/Emscripten 构建按目录 glob `bx/src/*.cpp`，会用 CMake `REMOVE_ITEM` 排除其中的 amalgamated.cpp（分文件编译与全量编译二选一，防止符号双重定义）；文件本身保留为上游原样 | 非源码修改，属构建布局约束 |
| bimg EAC 与图像处理 | bimg.h 枚举 + image.cpp 格式表/PVRTC mip | 随 bgfx EAC 上游化推进 |
| tinyexr 内置 miniz 保持删除 | 与 IppClub 上游共享状态一致；EXR 解压走 zlib（`TINYEXR_USE_MINIZ=0`） | 升级 bimg 时此目录的 modify/delete 冲突一律按"保持删除"解决 |
| miniz 去重（tinyexr） | 构建期 `TINYEXR_USE_MINIZ=0` + zlib，树内文件保留原样 | 非源码补丁，纯构建定义 |

## 已移除的侵入改动

- **DORA_LOVE_TRACE 诊断**（原 bgfx.cpp encoder 埋点 + renderer_gl 绘制循环诊断）
  已从 bgfx 树剥离（代码见 git 历史 739217688 等提交）。引擎侧仍有 `bgfx::setMarker`
  埋点（公开 API，RenderDoc 可见）；draw 统计可用 `bgfx::getStats()` 按 view 观测。
  如需重启 bgfx 内部诊断，从 git 历史恢复对应块或重写。
- **config.h 的 Linux D3D 默认移除**：改由 xmake 构建参数
  `BGFX_CONFIG_RENDERER_OPENGL=1` 注入。

## 引擎侧的 bgfx 配置点

- 渲染后端选择：`Tools/bgfx/xmake.lua` 的 `add_bgfx_renderer_config`
  （Windows=D3D11、Apple=Metal、Android/ARM-Linux=OpenGLES30、桌面 Linux=OpenGL）。
- `BGFX_CONFIG_MAX_FRAME_BUFFERS=256`、transient buffer 大小：前者在 xmake.lua，
  后者在 `Source/Basic/Application.cpp`（`BGFXDora::init`）。
- 嵌入式 shader：`bgfx_shader.sh` / `bgfx_compute.sh` 由 shaderc-lib 构建时 bin2c
  到 `Source/Shader/DoraShaderc/generated/`。
