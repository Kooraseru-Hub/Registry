# Registry

Registry is a Roblox Luau module manager with path-based registration, dependency ordering, and a lifecycle for setup, initialization, startup, and cleanup.

## Install

Download `Registry.zip` from [GitHub Releases](https://github.com/Kooraseru-Hub/Registry/releases) or import `source/Registry` from [main](https://github.com/Kooraseru-Hub/Registry/tree/main). Import the directory as a ModuleScript tree, using each `init.luau` as the ModuleScript for its containing directory. Put the tree in `ReplicatedStorage` for shared code or `ServerScriptService` for server-only code.

## Contribute

Open changes against `source`. With Node.js 24+ and Bash, run:

```sh
node dependencies/packages/core/dependencyLoader/index.ts
node dependencies/packages/core/dependencyLoader/index.ts --exec tools.ciEngine native-validate
```

Pushes to `source` and pull requests targeting it use the pinned CI Engine. To ship a version, merge its release record into `source`, then run the **Manual** workflow on `source` with **publish** selected and publication confirmed. The Engine stages the source archive, generates `main`, and publishes the release from the validated source commit.

Registry is dedicated to the public domain under [CC0 1.0](LICENSE).
