const win = @import("std").os.windows;
const wdk = @cImport({
    @cDefine("_AMD64_", "1");
    @cDefine("_KERNEL_MODE", "1");
    @cDefine("POOL_NX_OPTIN", "1");
    @cDefine("POOL_ZERO_DOWN_LEVEL_SUPPORT", "1");
    @cDefine("_UNICODE", "1");
    @cDefine("UNICODE", "1");
    @cInclude("ntifs.h");
    @cInclude("ntddk.h");
    @cInclude("wdm.h");
    @cInclude("ntstrsafe.h");
    @cInclude("ntimage.h");
    @cInclude("fltkernel.h");
});

pub fn driverEntry(_: wdk.PDRIVER_OBJECT, _: *const wdk.UNICODE_STRING) callconv(.C) wdk.NTSTATUS {
    const owo: *const [35:0]u8 = "OwO What's this? \nUwU *nuzzles you*";
    _ = wdk.DbgPrintEx(wdk.DPFLTR_IHVDRIVER_ID, wdk.DPFLTR_ERROR_LEVEL, owo);
    return 0;
}

comptime {
    @export(driverEntry, .{ .name = "DriverEntry" });
}
