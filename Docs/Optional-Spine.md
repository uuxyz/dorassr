# Optional Spine runtime

The CMake builds for Linux, Android and Web disable Spine by default. Windows MSBuild also disables it by default. Set `DORA_WITH_SPINE=ON` for the build scripts, or `DoraWithSpine=true` for MSBuild together with a Rust runtime built with its `spine` feature, to compile the existing Spine runtime. The Lua `Spine` class and its manual methods, Wasm imports, Rust API, Spine caches and version entry are absent when disabled. `Playable` and `Cache` return failure for Spine files. The standalone Rust SDK exposes Spine only with its `spine` Cargo feature.

The Studio editor uses a placeholder for Spine preview by default. To build a Studio bundle with Spine preview, install optional dependencies and set `DORA_WITH_SPINE=1` when running Vite. For a bundle without the player dependency, install with `pnpm install --no-optional` and leave the environment variable unset.

These switches control compiled binaries and Studio bundles. The repository still contains the Spine runtime sources, sample assets and the optional player entry in the package lockfile. A source distribution intended for repositories that reject nonfree source material must omit those files and audit the remaining assets and dependencies. The macOS and iOS Xcode projects still compile Spine; they need an equivalent source selection before their default builds can be considered Spine-free.
