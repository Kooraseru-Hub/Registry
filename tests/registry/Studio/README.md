# Registry test hosts

Build the fixture from [DataModel aliases](aliases.json) with `node tests/registry/Studio/build.cjs`. It writes a test place (`.rbxlx`) and an importable XML model (`.rbxmx`) to `build/artifacts/tests/studio`. The alias map also drives the editor sourcemap. The GitHub feature test verifies the generated hierarchy and embedded Luau.

## Local Studio

Run from the checkout root in MSYS2, Git Bash, or WSL. Install Roblox Studio on Windows and have Node.js on PATH. WSL also needs Windows interop and Windows `node.exe` on PATH to launch Studio. In VS Code, use **Registry: Verify in Studio** or **Registry: Benchmark and Build** (Ctrl+Shift+B) from a Windows workspace with MSYS2 at the default path or a Remote WSL workspace.

```bash
bash tests/registry/Studio/run.sh Lookup
bash tests/registry/Studio/benchmark-build.sh
```

The combined command writes four SVGs and the raw CSV into a fresh directory under `build/artifacts/benchmarks` and embeds the heatmaps in the generated README. Compare two revisions on the same machine with the same Studio version and workload. These tasks use the local test place and require no project credentials.

Set `ROBLOX_STUDIO_EXECUTABLE` to override Studio discovery or `STUDIO_TIMEOUT_SECONDS` to override the 600-second timeout. The runner builds a fresh local place and launches Studio in the background. Suites `RequireForms` and `Matrix` run the performance benchmarks. Logs and generated assets are stored under `build/artifacts/tests`.
