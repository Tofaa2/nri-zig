# nri-zig

Zig bindings for [NVIDIA-RTX/NRI](https://github.com/NVIDIA-RTX/NRI) (NRI v180, Zig 0.16.0).

## Requirements

- Zig 0.16.0
- cmake and a C++ compiler (needed to build the NRI library)
- A Vulkan-capable driver (or D3D12 on Windows)

NRI v180 is vendored in `thirdparty/nri`, so the repo is fully self-contained.

## Usage

Fetch and add to `build.zig.zon`:

```sh
zig fetch --save git+https://github.com/Tofaa2/nri-zig
```

Then in `build.zig`:

```zig
const nri_zig = b.dependency("nri_zig", .{ .target = target, .optimize = optimize });
exe.root_module.addImport("nri", nri_zig.module("root"));
// see build.zig for how libNRI itself is built and linked (buildNri)
```

Then in code:

```zig
const nri = @import("nri");

const device = try nri.createDevice(@intCast(nri.c.NriGraphicsAPI_VULKAN), 0, true);
const iface = try nri.getInterfaces(device); // .core, .swap, .helper, .mesh, .rt
```

The full NRI API is available through `nri.c` and the interface tables.

## Testing

```sh
cd test
zig build run   # builds libNRI + runs a consumer-style test (lists adapters)
```

The `test/` project consumes the library through a `.path` dependency, the
same way a real user would after `zig fetch`.

## License

MIT (the same license as NVIDIA NRI).