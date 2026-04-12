# Changelog

All notable changes to Registry are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] - 2026-04-10

### Added

- Introduced the new path-based registry system for hierarchical module organization.
- Added advanced path resolution with aliases, relative paths, and `@game` and `@self` support.
- Added explicit dependency declarations with validation and cycle detection.
- Added expanded lifecycle support with `Setup`, `Init`, `Start`, and `Destroy` stages.
- Added lifecycle helpers including `SetupAll()`, `InitAll()`, `StartAll()`, `DestroyAll()`, and `RunLifecycle()`.
- Added hook-based observability through `Registry:On()` event callbacks.
- Added inspection and debugging helpers such as `Inspect()`, `ListModules()`, and `GetErrors()`.
- Added per-module Maid integration for automatic cleanup during shutdown and reset flows.
- Added utility helpers including `GetDescendants()`, `GetByCategory()`, `IsRegistered()`, and `Reset()`.

### Changed

- Reworked Registry from the original name-based `Registry.lua` implementation into a path-based system.
- Replaced context-specific construction via `Registry.new("Server" | "Client" | "Shared")` with the new singleton-style registry workflow.
- Expanded startup ordering beyond category-only execution to support dependencies and per-module priorities.

### Breaking Changes

- Module registration now uses explicit paths instead of simple names.
- Module lookup now centers on path resolution instead of direct name or instance access.
- The old global `_G.Registry` access pattern is no longer the primary workflow.
- Projects using the old `Registry.lua` require migration to the new registration and lifecycle APIs.

---

## [1.0.1] - Initial release

### Added

- Released the original `Registry.lua` implementation.
- Added a lightweight name-based registry for central module registration.
- Added `Registry.new(context)` for `Server`, `Client`, and `Shared` registry instances.
- Added module registration by string name or `Instance`.
- Added module lookup by registered name or source instance.
- Added `InitAll()` to initialize registered modules.
- Added `StartAll()` for arbitrary-order startup.
- Added `StartOrdered()` for category-based startup sequencing.
- Added Luau type annotations and native optimization directives.

### Notes

- This release represents the original registry system preserved in `Registry.lua`.
- Version `1.1.0` replaces this design with the newer path-based Registry implementation.
