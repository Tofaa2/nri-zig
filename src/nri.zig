const std = @import("std");

pub const c = @cImport({
    @cInclude("NRI.h");
    @cInclude("NRIDeviceCreation.h");
    @cInclude("NRIHelper.h");
    @cInclude("NRIImgui.h");
    @cInclude("NRILowLatency.h");
    @cInclude("NRIMeshShader.h");
    @cInclude("NRIRayTracing.h");
    @cInclude("NRIStreamer.h");
    @cInclude("NRISwapChain.h");
    @cInclude("NRIUpscaler.h");
});

pub const Device = c.NriDevice;
pub const Queue = c.NriQueue;
pub const Fence = c.NriFence;
pub const SwapChain = c.NriSwapChain;
pub const CommandAllocator = c.NriCommandAllocator;
pub const CommandBuffer = c.NriCommandBuffer;
pub const Buffer = c.NriBuffer;
pub const Texture = c.NriTexture;
pub const Descriptor = c.NriDescriptor;
pub const Pipeline = c.NriPipeline;
pub const PipelineLayout = c.NriPipelineLayout;
pub const PipelineCache = c.NriPipelineCache;
pub const DescriptorPool = c.NriDescriptorPool;
pub const DescriptorSet = c.NriDescriptorSet;
pub const QueryPool = c.NriQueryPool;
pub const Memory = c.NriMemory;
pub const Result = c.NriResult;

pub fn ok(result: Result) bool {
    return result == c.NriResult_SUCCESS;
}

pub const SWAPCHAIN_SEMAPHORE = c.NRI_SWAPCHAIN_SEMAPHORE;
pub const log = std.log.scoped(.nri);

pub const GraphicsApiVk: c.NriGraphicsAPI = 8;

pub const Interfaces = struct {
    core: c.NriCoreInterface,
    swap: c.NriSwapChainInterface,
    helper: c.NriHelperInterface,
    mesh: c.NriMeshShaderInterface,
    rt: c.NriRayTracingInterface,
};

pub fn getRecommendedGfxApi() u8 {
    const builtin = @import("builtin");
    switch (builtin.os.tag) {
        .linux => c.NriGraphicsAPI_VK,
        .macos => c.NriGraphicsAPI_WGPU,
        .windows => c.NriGraphicsAPI_D3D12,
        .emscripten => c.NriGraphicsAPI_WGPU,
        else => c.NriGraphicsAPI_NONE,
    }
}

pub fn getInterfaces(device: *Device) !Interfaces {
    var ifs: Interfaces = undefined;
    try getInterface(device, "CoreInterface", &ifs.core);
    try getInterface(device, "SwapChainInterface", &ifs.swap);
    try getInterface(device, "HelperInterface", &ifs.helper);
    try getInterface(device, "MeshShaderInterface", &ifs.mesh);
    try getInterface(device, "RayTracingInterface", &ifs.rt);
    return ifs;
}

fn getInterface(device: *Device, comptime name: [*:0]const u8, out: anytype) !void {
    if (!ok(c.nriGetInterface(device, name, @sizeOf(@TypeOf(out.*)), out))) {
        log.err("nriGetInterface(\"{s}\") failed", .{name});
        return error.NriInterfaceFailed;
    }
}

fn messageCallback(
    message_type: c.NriMessage,
    file: [*c]const u8,
    line: u32,
    message: [*c]const u8,
    user_arg: ?*anyopaque,
) callconv(.c) void {
    _ = user_arg;
    const level: std.log.Level = switch (message_type) {
        c.NriMessage_ERROR => .err,
        c.NriMessage_WARNING => .warn,
        else => .info,
    };

    const m_file = std.mem.span(file);
    const m_message = std.mem.span(message);

    switch (level) {
        .warn => log.warn("{s}:{d} {s}", .{ m_file, line, m_message }),
        .debug => log.debug("{s}:{d} {s}", .{ m_file, line, m_message }),
        .err => log.err("{s}:{d} {s}", .{ m_file, line, m_message }),
        .info => log.info("{s}:{d} {s}", .{ m_file, line, m_message }),
    }

    //    const func = switch (level) {
    //        .warn => log.warn,
    //        .debug => log.debug,
    //        .err => log.err,
    //        .info => log.info,
    //    };
    //    func("{s}:{d} {s}", .{
    //        std.mem.span(file),
    //        line,
    //        std.mem.span(message),
    //    });
}

pub fn enumerateAdapters(out: []c.NriAdapterDesc) usize {
    var num: u32 = 0;
    if (!ok(c.nriEnumerateAdapters(null, &num))) return 0;
    const count = @min(num, @as(u32, @intCast(out.len)));
    if (count == 0) return 0;
    var cap: u32 = count;
    if (!ok(c.nriEnumerateAdapters(out.ptr, &cap))) return 0;
    return count;
}

pub fn createDevice(graphics_api: c.NriGraphicsAPI, adapter_index: u32, enable_validation: bool) !*Device {
    var adapters: [16]c.NriAdapterDesc = undefined;
    const adapter_num = enumerateAdapters(&adapters);
    if (adapter_index >= adapter_num) return error.NriAdapterNotFound;

    var desc: c.NriDeviceCreationDesc = std.mem.zeroes(c.NriDeviceCreationDesc);
    desc.graphicsAPI = graphics_api;
    desc.adapterDesc = &adapters[adapter_index];
    desc.callbackInterface.MessageCallback = messageCallback;
    desc.enableNRIValidation = enable_validation;

    var device: ?*Device = null;
    if (!ok(c.nriCreateDevice(&desc, &device))) return error.NriCreateDeviceFailed;
    return device.?;
}
