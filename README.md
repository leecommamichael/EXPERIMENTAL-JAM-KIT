## Jam Kit
This is my monorepo for portable app development.

My goal is to be self-sufficient in the technique required to write high-quality, portable software. Because this is an ambitious goal, I do currently use the stb libraries for decoding some asset file formats for textures and audio, but there may be a day when I find it personally beneficial to write those myself here in this codebase.

Capabilities:
- [x] Basic GPU Accelerated 3D lighting
- [x] Animated Sprites
- [x] Flexible Row/Column UI library
- [x] Hot-Reloading for Code
- [x] Hot-Reloading for GPU Shaders
- [ ] Hot-Reloading of assets
- [x] Basic Physics capabilities
- [x] Fixed-timestep simulation for portable/networked physics
- [x] Physics debug overlay to visualize colliders
- [x] Gamepad Input
- [x] Games-oriented Audio interface
- [x] Games-oriented key-value persistence API

Platforms:
- [x] Windows
- [x] Web
- [x] macOS
- [x] Linux (Wayland)
- [x] Linux (Embedded)
- [ ] iOS
- [ ] Android

### Subpackage `sugar`
Platform abstraction layer. Provides windowing and input.

### Subpackage `angle`
A safe and debuggable interface to OpenGL ES 3.x on all platforms. Named for Google's ANGLE project, which powers WebGL. This package can load functions from either the platform-native OpenGL DLL or Google's ANGLE DLL.
