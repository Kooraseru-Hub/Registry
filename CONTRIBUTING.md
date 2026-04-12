# Contributing to Registry

Thank you for your interest in contributing to Registry! This document provides guidelines and instructions for contributing to the project.

---

## Getting Started

### Prerequisites

- **Luau/Roblox Studio** for testing changes
- **Git** for version control
- Basic understanding of the Registry system (see [README.md](README.md))

### Setting Up the Development Environment

1. **Fork the Repository**
   ```bash
   # Visit https://github.com/Kooraseru-Hub/Registry and click "Fork"
   ```

2. **Clone Your Fork**
   ```bash
   git clone https://github.com/Kooraseru-Hub/Registry.git
   cd Registry
   ```

3. **Create a Feature Branch**
   ```bash
   git checkout -b feature/your-feature-name
   # or for bug fixes:
   git checkout -b bugfix/issue-description
   ```

---

## Development Workflow

### Code Style

Registry enforces consistent code style via `.rules/` directory conventions:

1. **Follow Luau Style Rules** (`.rules/luau/`)
   - **Naming**: Use PascalCase for module functions, SCREAMING_SNAKE_CASE for constants
   - **Functions**: Use method syntax (`:`) by default, include type annotations
   - **Comments**: Include path labels, directives, and documentation blocks

2. **Example Module Structure**
   ```lua
   -- path/to/Module.luau
   --!strict
   --!optimize 2

   local Types = require("@self/Types")

   --[[
       Public module description.
       @param registry Registry The module registry instance
       @return Module The initialized module
   ]]
   local MyModule = {
       Category = "Systems",
       Priority = 10,

       Init = function(self, registry: Registry, path: string)
           -- Implementation
       end,
   }

   return MyModule
   ```

3. **Key Points**
   - Always include `-- path/to/file.luau` as the first line
   - Use `--!strict` and `--!optimize 2` directives
   - Document public functions with block comments
   - Use type annotations for parameters and returns
   - Prefer `:` over `.` for method definitions

### Testing

Before submitting a pull request:

> [!IMPORTANT]
> Test all changes in Roblox Studio. Verify module registration, resolution, lifecycle stages, and error scenarios before opening a PR.

1. **Manual Testing**
   - Test your changes in Roblox Studio
   - Verify module registration and resolution work correctly
   - Test lifecycle stages and dependencies
   - Run error scenarios and edge cases

2. **Integration Testing**
   ```lua
   -- Example test structure
   local Registry = require("@self/Registry")

   -- Test registration
   Registry:Register("Test/Module", {
       Init = function(self, registry, path)
           print("Module initialized at:", path)
       end
   })

   -- Test resolution
   local module = Registry:Get("Test/Module")
   assert(module ~= nil, "Module should be registered")

   -- Test lifecycle
   Registry:RunLifecycle()
   ```

3. **Verify Existing Tests Pass**
   - Ensure your changes don't break existing functionality
   - Test path resolution with various prefix styles
   - Test category ordering and priorities
   - Verify dependency validation

---

## Submitting Changes

### Commit Messages

Follow conventional commit format:

```
type(scope): brief description

Optional body explaining the why and what.

Fixes #issue-number
```

**Types:**
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `style:` Code style changes (formatting, etc.)
- `refactor:` Code refactoring without feature change
- `test:` Adding or updating tests
- `chore:` Maintenance tasks

**Examples:**
```
feat(resolution): add custom alias support
fix(lifecycle): resolve module dependency deadlock in Init stage
docs(readme): update API reference with new methods
refactor(core): simplify path resolution logic
```

### Pull Request Process

1. **Before Creating PR**
   - Ensure all changes follow code style rules from `.rules/`
   - Test thoroughly in Roblox Studio
   - Update documentation if adding/changing features
   - Run through the checklist below

2. **Create a Pull Request**
   - Use a clear, descriptive title
   - Reference related issues (`Fixes #123`, `Related to #456`)
   - Provide a summary of changes
   - Describe how to test the changes

3. **PR Checklist**
   - [ ] Code follows `.rules/` conventions
   - [ ] All lifecycle stages tested (Setup, Init, Start, Destroy)
   - [ ] Dependencies are properly resolved
   - [ ] No console errors or warnings introduced
   - [ ] Documentation updated if needed
   - [ ] Examples included for new features
   - [ ] Commit messages follow conventional format

4. **Code Review**

> [!NOTE]
> Address review feedback promptly. Discuss concerns respectfully and request clarification if review comments are unclear. Changes may be requested before merging.

---

## Types of Contributions

### Bug Reports

> [!TIP]
> Search existing issues at [Kooraseru-Hub/Registry](https://github.com/Kooraseru-Hub/Registry/issues) before filing a new report. Add to an existing issue if yours is already covered.

Found an issue? Please follow these guidelines:

1. **Search Existing Issues**
   - Check if your issue has already been reported
   - Add to existing issues if applicable

2. **Report Template**
   ```
   **Describe the bug:**
   Clear, concise description of what's happening

   **Environment:**
   - Roblox Studio version: 
   - Registry version: 

   **Steps to reproduce:**
   1. Register a module...
   2. Call RunLifecycle()...
   3. Error occurs...

   **Expected behavior:**
   What should happen

   **Actual behavior:**
   What actually happens

   **Code sample:**
   -- Your minimal code example
   ```

### Feature Requests

Have an idea to improve Registry? Help us understand:

1. **Description**
   - What problem does this solve?
   - Why is it needed?
   - How would you use it?

2. **Proposed Solution**
   - Code example or API design
   - How it fits with existing features
   - Potential impact on performance/compatibility

3. **Alternatives Considered**
   - Other approaches you've thought about
   - Why your solution is better

### Documentation Improvements

> [!NOTE]
> Documentation updates are valuable contributions. Even small fixes like typos or clearer examples make a real difference.

You can:

- Fix typos and clarification
- Add examples and use cases
- Improve code snippet formatting
- Update API docs

---

## Code Review Guidelines

### For Contributors

- **Be open to feedback**: Reviews aim to improve code quality
- **Ask questions**: If review comments are unclear, ask
- **Suggest alternatives**: If you disagree, propose solutions
- **Keep discussions professional**: Focus on code, not people

### For Reviewers

- **Be constructive**: Suggest improvements, not just problems
- **Explain the why**: Help contributors understand reasoning
- **Acknowledge effort**: Thank contributors for their work
- **Be timely**: Review and respond within a reasonable timeframe

---

## Project Structure

```
Registry/
├── .rules/                  -- Style and convention rules
│   └── luau/               -- Luau-specific rules
├── .github/                -- GitHub integration
│   ├── ISSUE_TEMPLATE/     -- Issue templates
│   └── PULL_REQUEST_TEMPLATE/
├── src/
│   └── Registry/           -- Main module
│       ├── Core/           -- Core functionality
│       ├── Hooks/          -- Event system
│       ├── Stages/         -- Lifecycle stages
│       └── Utilities/      -- Helpers
├── README.md               -- Main documentation
├── CHANGELOG.md            -- Version history
├── CONTRIBUTING.md         -- This file
└── LICENSE                 -- CC0 1.0 Universal License
```

---

## Common Tasks

### Adding a New Core Feature

1. **Create feature branch**
   ```bash
   git checkout -b feature/your-feature
   ```

2. **Implement in appropriate module**
   - Core features go in `src/Registry/Core/`
   - Hooks in `src/Registry/Hooks/`
   - Stages in `src/Registry/Stages/`

3. **Update exports in `init.luau`**
   ```lua
   export type YourType = Types.YourType
   ```

4. **Add method to Registry type**
   ```lua
   -- In Types.luau
   YourNewMethod: (self: Registry, ...) -> ...
   ```

5. **Test thoroughly**
   - Module isolation
   - Integration with existing features
   - All lifecycle stages

6. **Update documentation**
   - README.md with examples
   - Code comments following `.rules/`
   - CHANGELOG.md with changes

### Fixing a Bug

1. **Create test case** that reproduces the bug
2. **Create bugfix branch**
   ```bash
   git checkout -b bugfix/issue-name
   ```
3. **Implement fix** with minimal changes
4. **Verify test passes** and no regressions
5. **Document fix** in code comments
6. **Update CHANGELOG.md** under `[Unreleased]`

### Improving Documentation

1. **Fork and clone** the repository
2. **Make documentation changes** in relevant `.md` files
3. **Preview** changes locally if possible
4. **Submit PR** with clear description of improvements

---

## Getting Help

> [!TIP]
> Start with [README.md](README.md) and existing issues for most questions. If still unclear, comment on a relevant GitHub issue or open a new one with reproduction steps.

---

## Recognition

All contributors are recognized in the community. Major contributions may be acknowledged in project documentation and release notes.

Thank you for contributing to Registry! Your efforts help make this project better for everyone. 🙏

---

## Additional Resources

- [Keep a Changelog](https://keepachangelog.com/): Changelog format reference
- [Conventional Commits](https://www.conventionalcommits.org/): Commit message standard
- [Contributor Covenant](https://www.contributor-covenant.org/): Code of Conduct basis
- [Semantic Versioning](https://semver.org/): Versioning standard used by Registry

