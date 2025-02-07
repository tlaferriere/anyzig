# anyzig

Replaces your system-wide version-specific `zig` with a universal one.

This removes the limitation that you can only have one version of Zig in your path.

Utilizes the global cache to store each version of zig. Adding a new version is equivalent to running `zig fetch ZIG_DOWNLOAD_URL`.

With anyzig, if you run `zig` from a directory that contains a `build.zig.zon` file (or if any parent directory contains one) it will determine which version of zig to invoke based on the `minimum_zig_version`.


`build.zig.zon`:

```zig
.{
    .name = "myproject",
    .version = "0.0.0",
    .minimum_zig_version = "0.13.0",
}
```

In addition, you can also specify the version of zig to invoke for any single command, i.e.

```sh
$ zig 0.13.0 build-exe myproject.zig
$ zig 0.14.0-dev.3028+cdc9d65b0 build-exe mynewerproject.zig
```

# Notes

> NOTE: is there any reason to support an alternative mechanism to declare which version of zig to use?

> NOTE: should we have a command to override the minimum_zig_version in the zon file?

> NOTE: If there is no `build.zig.zon`, anyzig could try to use a set of heuristics to determine which version of zig should be used.  Once it's determined, it could create a `build.zig.zon` file (or alternative) and save the version there.

> NOTE: It might be worth trying to detect if anyzig is being run by a user interactively and query the user to enter a version or choose a setting when the version is ambiguous and/or there's some decision to be made.  For example, if a user just runs `zig init` without a version, it *could* be interesting to query them for the version instead of exiting with an error.
