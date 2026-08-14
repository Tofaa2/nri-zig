# nri-zig

Zig bindings for [NVIDIA-RTX/NRI](https://github.com/NVIDIA-RTX/NRI) (NVIDIA
Rendering Interface), targeting **NRI v180** and **Zig 0.16.0**.

The bindings are a thin wrapper around the v180 C headers: `src/nri.zig`
`@cImport`s all 10 `NRI*.h` headers (core, device creation, helper, imgui,
low-latency, mesh shader, ray tracing, streamer, swap chain, upscaler) and
adds a few ergonomic helpers on top. All calls go through the per-device
interface tables filled by `nriGetInterface` (`nri.getInterfaces`), exactly
like the official NRI API.

## Cloning

```sh
git clone --recursive https://github.com/Tofaa2/nri-zig
```

or, if already cloned:

```sh
git submodule update --init
```

NRI itself is pinned as a git submodule at `thirdparty/nri` (tag `v180`).

## Dependencies

- Zig 0.16.0
- `cmake` + a C++ compiler (`g++`/`clang`, or MSVC on Windows) — only needed to
  build `libNRI` from the submodule (see `buildNri` below)
- To **run** NRI (any backend): a Vulkan-capable driver (or D3D12 on Windows)

## Usage

Add it to `build.zig.zon`:

```zig
.dependencies = .{
    .nri_zig = .{
        .url = "https://path/to/nri-zig/archive/refs/tags/v0.1.0.tar.gz",
        .hash = "...",
    },
},
```

Then use it in `build.zig`:

```zig
const nri_zig = b.dependency("nri_zig", .{ .target = target, .optimize = optimize });
exe.root_module.addImport("nri", nri_zig.module("root"));
```

The module already carries the NRI include paths, and links libc/libc++.

To build and link `libNRI` (shared, from the submodule via cmake), call:

```zig
_ = nri_zig.buildNri(b, exe, optimize, target);
```

```zig
const nri = @import("nri");

// Device + interfaces
const device = try nri.createDevice(@intCast(nri.c.NriGraphicsAPI_VULKAN), 0, builtin.mode == .Debug);
const iface = try nri.getInterfaces(device); // .core, .swap, .helper, .mesh, .rt

// Usable immediately
var queue: ?*nri.Queue = null;
if (!nri.ok(iface.core.GetQueue.?(device, @intCast(nri.c.NriQueueType_GRAPHICS), 0, &queue))) ...
```

## API notes (v180 quirks)

- Everything is C-style: enums/consts live on `nri.c` (`nri.c.NriStageBits_COLOR_ATTACHMENT`,
  `nri.c.NriLayout_PRESENT`, ...) as `c_int`; struct fields expect the typedef
  width (u8/u32), so `@intCast` at call sites.
- Interface functions are optional: `iface.core.CreateBuffer.?(...)`.
- `StageBits::NONE` = `0x7FFFFFFF`, `StageBits::ALL` = `0`;
  `AccessBits::COLOR_ATTACHMENT` = `(1<<5)|(1<<6)`.
- `Layout::PRESENT` barriers require `AccessBits::NONE` + `StageBits::NONE`.
- Swapchain fences start at `nri.SWAPCHAIN_SEMAPHORE` (`~0`); the queue
  submit value for them is `0`.
- Dynamic rendering only — no render-pass objects.
- No `QueueSignal`/`WaitIdle`: use `Wait(fence, value)`, `DeviceWaitIdle`,
  `QueueWaitIdle`.

## Building this repo

```sh
zig build       # builds libNRI (cmake) + nri-example
zig build run   # prints the adapter list
```

## License

MIT — the same license as NVIDIA NRI (see `LICENSE`, and
`thirdparty/nri/LICENSE.txt` inside the submodule).