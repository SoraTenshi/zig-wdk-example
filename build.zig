const std = @import("std");
const builtin = @import("builtin");

const MAX_PATH = std.os.windows.MAX_PATH;

const stderr = std.io.getStdErr().writer();

fn checkForEnvVariable(comptime path: []const u8, alloc: std.mem.Allocator, comptime example_path: []const u8, is_path: bool) ![]u8 {
    const res = std.process.getEnvVarOwned(alloc, path) catch |e| {
        switch (e) {
            std.process.GetEnvVarOwnedError.EnvironmentVariableNotFound => {
                try stderr.print("Environment Variable {s} not found.\n", .{path});
                try stderr.print("Make sure that the env variable looks like: '{s}'!\n", .{example_path});
                return e;
            },
            else => return e,
        }
    };

    if (is_path and (!std.fs.path.isAbsolute(res) and !std.fs.path.windowsParsePath(res).is_abs)) {
        try stderr.print("'{s}' is not a path", .{res});
        return error.NotAPath;
    }

    return res;
}

pub fn build(b: *std.Build) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const wdk = try checkForEnvVariable("WDK_PATH", alloc, "/mnt/c/Program Files (x86)/Windows Kits/10/Include/", true);
    const vs = try checkForEnvVariable("VS_INCLUDE", alloc, "/mnt/c/Program Files/Microsoft Visual Studio/2022/Preview/VC/Tools/MSVC/14.40.33521/include/", true);
    const version = try checkForEnvVariable("WDK_VERSION", alloc, "10.0.22621.0", false);
    const other_version = try checkForEnvVariable("WDK_SHARED_VERSION", alloc, "10.0.22000.0", false);

    const optimize = b.standardOptimizeOption(.{});

    const obj = b.addObject(.{
        .name = "wdk-zig",
        .root_source_file = b.path("src/main.zig"),
        .target = b.resolveTargetQuery(.{
            .os_tag = .windows,
            .abi = .msvc,
        }),
        .optimize = optimize,
    });

    const km = try std.fs.path.join(alloc, &.{ wdk, version, "km" });
    const shared = try std.fs.path.join(alloc, &.{ wdk, other_version, "shared" });
    const ucrt = try std.fs.path.join(alloc, &.{ wdk, other_version, "ucrt" });

    obj.addIncludePath(.{ .path = vs });
    obj.addIncludePath(.{ .path = km });
    obj.addIncludePath(.{ .path = shared });
    obj.addIncludePath(.{ .path = ucrt });

    const install_step = b.addInstallArtifact(obj, .{
        .dest_dir = .{ .override = .{ .custom = "obj" } },
    });

    const lib_path_base = try checkForEnvVariable("WDK_LIB_PATH", alloc, "C:\\Program Files (x86)\\Windows Kits\\10\\Lib\\10.0.22621.0'; '(MAKE SURE THIS IS THE WINDOWS PATH!!)", true);
    const lib_path = try std.fs.path.join(alloc, &.{ lib_path_base, "km\\x64" });
    const lib = try std.fmt.allocPrint(alloc, "/LIBPATH:{s}", .{lib_path});

    const mk_driver = b.addSystemCommand(&.{ "mkdir", "-p", "./zig-out/driver/" });
    const linking_step = b.addSystemCommand(&.{
        "link.exe",
        "/TIME",
        "/DEBUG",
        "/DRIVER",
        "/NODEFAULTLIB",
        "/NODEFAULTLIB:libucrt.lib",
        "/NODEFAULTLIB:libucrtd.lib",
        "/SUBSYSTEM:NATIVE",
        "/ENTRY:DriverEntry",
        "/NODEFAULTLIB:msvcrt.lib",
        "/OPT:REF",
        "/OPT:ICF",
        lib,
        "ntoskrnl.lib",
        "hal.lib",
        "wmilib.lib",
        "./zig-out/obj/wdk-zig.obj",
        "/OUT:./zig-out/driver/owo.sys",
        "/PDB:./zig-out/driver/owo.pdb",
        "/MAP:./zig-out/driver/owo.map",
    });

    linking_step.step.dependOn(&mk_driver.step);
    b.getInstallStep().dependOn(&install_step.step);
    b.getInstallStep().dependOn(&linking_step.step);
}
