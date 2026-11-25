# Registry CI

Native workflows invoke project-owned scripts directly. CI-Packages owns release publication, generated branch publication, Roblox model encoding and DevForum post verification. Registry owns historical source-layout selection, its Starlight renderer, chart generation and image cache. The Publish workflow is rehearsal-only unless explicitly dispatched from source with a publication target. Actual branch publication uses the ci-devforum environment and persists the verified cache on main. Benchmark uses roblox-test. No scheduler is installed.
