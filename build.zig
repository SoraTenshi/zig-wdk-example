const std = @import("std");
const builtin = @import("builtin");

const MAX_PATH = std.os.windows.MAX_PATH;

const stderr = std.io.getStdErr().writer();

const log = std.log.scoped(.Build);

fn checkForEnvVariable(comptime path: []const u8, alloc: std.mem.Allocator, comptime example_path: []const u8, is_path: bool) ![]u8 {
    _ = example_path; // autofix
    const res = std.process.getEnvVarOwned(alloc, path) catch |e| {
        switch (e) {
            std.process.GetEnvVarOwnedError.EnvironmentVariableNotFound => {
                // try stderr.print("Environment Variable {s} not found.\n", .{path});
                // try stderr.print("Make sure that the env variable looks like: '{s}'!\n", .{example_path});
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

fn addSystemIncludes(
    self: *std.Build.Step.TranslateC,
    vs_includes: *std.mem.SplitIterator(u8, .scalar),
    km: []const u8,
    shared: []const u8,
    ucrt: []const u8,
    crt_path: []const u8,
) void {
    while (vs_includes.next()) |vs| {
        self.addIncludeDir(vs);
    }

    self.addIncludeDir(km);
    self.addIncludeDir(shared);
    self.addIncludeDir(ucrt);
    self.addIncludeDir(crt_path);
}

fn addDefaultVars(c: *std.Build.Step.TranslateC) void {
    c.defineCMacro("_AMD64_", "1");
    c.defineCMacro("_KERNEL_MODE", "1");
    c.defineCMacro("POOL_NX_OPTIN", "1");
    c.defineCMacro("POOL_ZERO_DOWN_LEVEL_SUPPORT", "1");
    c.defineCMacro("_MSC_VER", "1300");
}

fn useTranslateC(
    b: *std.Build,
    obj: *std.Build.Step.Compile,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    ntifs_path: []const u8,
    ntddk_path: []const u8,
    wdm_path: []const u8,
    ntstrsafe_path: []const u8,
    ntimage_path: []const u8,
    fltkernel_path: []const u8,
    vs_includes: *std.mem.SplitIterator(u8, .scalar),
    km: []const u8,
    shared: []const u8,
    ucrt: []const u8,
    crt_path: []const u8,
) void {
    const ntifs = b.addTranslateC(.{
        .root_source_file = std.Build.LazyPath{ .cwd_relative = ntifs_path },
        .target = target,
        .optimize = optimize,
        .use_clang = false,
    });

    const ntddk = b.addTranslateC(.{
        .root_source_file = std.Build.LazyPath{ .cwd_relative = ntddk_path },
        .target = target,
        .optimize = optimize,
        .use_clang = false,
    });

    const wdm = b.addTranslateC(.{
        .root_source_file = std.Build.LazyPath{ .cwd_relative = wdm_path },
        .target = target,
        .optimize = optimize,
        .use_clang = false,
    });

    const ntstrsafe = b.addTranslateC(.{
        .root_source_file = std.Build.LazyPath{ .cwd_relative = ntstrsafe_path },
        .target = target,
        .optimize = optimize,
        .use_clang = false,
    });

    const ntimage = b.addTranslateC(.{
        .root_source_file = std.Build.LazyPath{ .cwd_relative = ntimage_path },
        .target = target,
        .optimize = optimize,
        .use_clang = false,
    });

    const fltkernel = b.addTranslateC(.{
        .root_source_file = std.Build.LazyPath{ .cwd_relative = fltkernel_path },
        .target = target,
        .optimize = optimize,
        .use_clang = false,
    });
    addSystemIncludes(ntifs, vs_includes, km, shared, ucrt, crt_path);
    addSystemIncludes(ntddk, vs_includes, km, shared, ucrt, crt_path);
    addSystemIncludes(wdm, vs_includes, km, shared, ucrt, crt_path);
    addSystemIncludes(ntstrsafe, vs_includes, km, shared, ucrt, crt_path);
    addSystemIncludes(ntimage, vs_includes, km, shared, ucrt, crt_path);
    addSystemIncludes(ntimage, vs_includes, km, shared, ucrt, crt_path);
    addSystemIncludes(fltkernel, vs_includes, km, shared, ucrt, crt_path);

    addDefaultVars(ntifs);
    addDefaultVars(ntddk);
    addDefaultVars(wdm);
    addDefaultVars(ntstrsafe);
    addDefaultVars(ntimage);
    addDefaultVars(ntimage);
    addDefaultVars(fltkernel);

    obj.root_module.addImport("ntifs", ntifs.createModule());
    obj.root_module.addImport("ntddk", ntddk.createModule());
    obj.root_module.addImport("wdm", wdm.createModule());
    obj.root_module.addImport("ntstrsafe", ntstrsafe.createModule());
    obj.root_module.addImport("ntimage", ntimage.createModule());
    obj.root_module.addImport("fltkernel", fltkernel.createModule());
}

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.resolveTargetQuery(.{
        .os_tag = .windows,
        .abi = .msvc,
    });

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const wdk = checkForEnvVariable("WDK_PATH", alloc, "/mnt/c/Program Files (x86)/Windows Kits/10/Include/", true) catch "/mnt/c/Program Files (x86)/Windows Kits/10/Include/";
    const vs = checkForEnvVariable("INCLUDE", alloc, "/mnt/c/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.41.34120/include/", true) catch "/mnt/c/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.41.34120/include";
    const version = checkForEnvVariable("WDK_VERSION", alloc, "10.0.22621.0", false) catch "10.0.26100.0";
    const other_version = checkForEnvVariable("WindowsSDKVersion", alloc, "10.0.22000.0", false) catch "10.0.26100.0";
    const lib_path_base = checkForEnvVariable("WDK_LIB_PATH", alloc, "C:\\Program Files (x86)\\Windows Kits\\10\\Lib\\10.0.26100.0'; '(MAKE SURE THIS IS THE WINDOWS PATH!!)", true) catch "C:\\Program Files (x86)\\Windows Kits\\10\\Lib\\10.0.26100.0";
    var vs_includes = std.mem.splitScalar(u8, wdk, ';');

    const km = try std.fs.path.join(alloc, &.{ wdk, version, "km" });
    const ntifs_path = try std.fs.path.join(alloc, &.{ km, "ntifs.h" });
    const ntddk_path = try std.fs.path.join(alloc, &.{ km, "ntddk.h" });
    const wdm_path = try std.fs.path.join(alloc, &.{ km, "wdm.h" });
    const ntstrsafe_path = try std.fs.path.join(alloc, &.{ km, "ntstrsafe.h" });
    const ntimage_path = try std.fs.path.join(alloc, &.{ km, "ntimage.h" });
    const fltkernel_path = try std.fs.path.join(alloc, &.{ km, "fltKernel.h" });
    const shared = try std.fs.path.join(alloc, &.{ wdk, other_version, "shared" });
    const ucrt = try std.fs.path.join(alloc, &.{ wdk, other_version, "ucrt" });
    const crt_path = try std.fs.path.join(alloc, &.{ km, "crt" });

    const obj = b.addObject(.{
        .name = "wdk-zig",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // useTranslateC(
    //     b,
    //     obj,
    //     target,
    //     optimize,
    //     ntifs_path,
    //     ntddk_path,
    //     wdm_path,
    //     ntstrsafe_path,
    //     ntimage_path,
    //     fltkernel_path,
    //     &vs_includes,
    //     km,
    //     shared,
    //     ucrt,
    //     crt_path,
    // );
    const define = b.addTranslateC(.{
        .root_source_file = b.path("defines/defines.h"),
        .target = target,
        .optimize = optimize,
        // .use_clang = false,
    });

    log.info("path: '{s}'", .{vs});
    log.info("path: '{s}'", .{km});
    log.info("path: '{s}'", .{shared});
    log.info("path: '{s}'", .{ucrt});

    while (vs_includes.next()) |inc| {
        define.addIncludeDir(inc);
    }
    define.addIncludeDir(km);
    define.addIncludeDir(shared);
    define.addIncludeDir(ucrt);
    define.addIncludeDir(crt_path);
    define.addIncludeDir(ntifs_path);
    define.addIncludeDir(ntddk_path);
    define.addIncludeDir(wdm_path);
    define.addIncludeDir(ntstrsafe_path);
    define.addIncludeDir(ntimage_path);
    define.addIncludeDir(fltkernel_path);

    obj.root_module.addImport("wdk", define.createModule());

    const install_step = b.addInstallArtifact(obj, .{
        .dest_dir = .{ .override = .{ .custom = "obj" } },
    });

    const lib_path = try std.fs.path.join(alloc, &.{ lib_path_base, "km\\x64" });
    const lib = try std.fmt.allocPrint(alloc, "/LIBPATH:{s}", .{lib_path});

    log.info("path: '{s}'", .{lib_path});

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
