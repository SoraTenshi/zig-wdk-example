# zig-wdk-example

This is an experiment to build a Windows Driver (with the WDK) in Zig.

There are some rough edges, e.g. that the `wdm.h` and `ntifs.h` aren't perfectly yet translated to Zig [see Issue #1499](https://github.com/ziglang/zig/issues/1499).

Just edit the `cimport.zig` in the `zig-cache` to align with the memory layout of those `extern struct`s, and it should work
<details>In this example, it was enough to change every `opaque {}` type with `*anyopaque` but this is possibly dangerous.</details>

Also this features a fully functional build script that when executed automagically builds the driver.
see `build.exe` for a list of todos (just check the calls to `checkForEnvVariable`) ;)


Good Luck, Soldier!
