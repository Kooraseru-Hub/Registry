# Registry test hosts

Build the fixture from [DataModel aliases](aliases.json) with `python tests/registry/Studio/build.py`. It writes a test place (`.rbxlx`) and an importable XML model (`.rbxmx`) to `build/studio`. The alias map also drives the editor sourcemap. The GitHub feature test verifies the generated hierarchy and embedded Luau.

## Local Studio

Run `bash tests/registry/Studio/run.sh Lookup` from MSYS2 with the Windows Python launcher (`py`) and Roblox Studio installed. Set `ROBLOX_STUDIO_EXECUTABLE` to override Studio discovery or `STUDIO_TIMEOUT_SECONDS` to override the 600-second timeout. The runner builds a fresh local place and launches Studio in the background. Suites `RequireForms` and `Matrix` run the performance benchmarks. Logs and generated assets are stored under `build/studio-runner`.
