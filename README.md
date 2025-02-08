# anyzig

A universal zig that works with any version. The version of zig to invoke is pulled from the `minimum_zig_version` field of `build.zig.zon`.

Anytime a new zig version is needed, anyzig will invoke the equivalent of `zig fetch ZIG_DOWNLOAD_URL` to download it into the global cache.

In addition, you can also specify the version of zig to invoke, i.e.

```sh
$ zig 0.13.0 build-exe myproject.zig
$ zig 0.14.0-dev.3028+cdc9d65b0 build-exe mynewerproject.zig
```

# TODO

- make it easy to configure anyzig and share that configuration accross machines
- add a "hook" concept that allows the user to run a command for every new version of zig. anyzig should also track anytime it has run a hook for a new version of zig so that if a hook is added, it will re-run that hook for all existing zig versions

# Notes

> NOTE: is there any reason to support an alternative mechanism to declare which version of zig to use?

> NOTE: should we have a command to override the minimum_zig_version in the zon file?

> NOTE: If there is no `build.zig.zon`, anyzig could try to use a set of heuristics to determine which version of zig should be used.  Once it's determined, it could create a `build.zig.zon` file (or alternative) and save the version there.

> NOTE: It might be worth trying to detect if anyzig is being run by a user interactively and query the user to enter a version or choose a setting when the version is ambiguous and/or there's some decision to be made.  For example, if a user just runs `zig init` without a version, it *could* be interesting to query them for the version instead of exiting with an error.
