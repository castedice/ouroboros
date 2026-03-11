# Project Detection Patterns

> Reference for `/adopt` Phase 2 (Codebase Scan).
> Glob patterns and config files used to detect project language, framework, conventions, and AI configuration.

## 2a: Language & Framework Detection

### Root Manifest Files

| Glob Pattern | Indicates |
|-------------|-----------|
| `package.json` | Node.js |
| `Cargo.toml` | Rust |
| `go.mod` | Go |
| `pyproject.toml`, `setup.py`, `requirements.txt` | Python |
| `Gemfile` | Ruby |
| `build.gradle*`, `pom.xml` | Java/Kotlin |
| `tsconfig.json` | TypeScript |
| `Makefile`, `CMakeLists.txt` | C/C++ |
| `docker-compose.yml`, `Dockerfile` | Docker |

### Directory Structure Globs

| Glob Pattern | Purpose |
|-------------|---------|
| `{project-path}/*` | Top-level structure |
| `{project-path}/src/**` | Source directory (one level deep) |
| `{project-path}/test*/**`, `{project-path}/*test*/**` | Test directory |

## 2b: Convention Indicators

### Linting & Formatting

| Config Files | Ecosystem |
|-------------|-----------|
| `.eslintrc*`, `.prettierrc*`, `biome.json`, `.editorconfig` | JavaScript/TypeScript |
| `rustfmt.toml` | Rust |
| `.golangci.yml` | Go |
| `ruff.toml` | Python |
| `.rubocop.yml` | Ruby |

### CI/CD

| Config Files | Platform |
|-------------|----------|
| `.github/workflows/*.yml` | GitHub Actions |
| `.gitlab-ci.yml` | GitLab CI |
| `Jenkinsfile` | Jenkins |
| `.circleci/config.yml` | CircleCI |

### Documentation

| File/Directory | Type |
|---------------|------|
| `README.md`, `CONTRIBUTING.md`, `CHANGELOG.md` | Standard docs |
| `docs/` | Documentation directory |
| `CLAUDE.md` | Existing Claude Code instructions |

## 2c: AI Configuration Files

| File/Directory | Tool |
|---------------|------|
| `AGENTS.md` | Multi-model (AAIF standard) |
| `CLAUDE.md` | Claude Code |
| `.codex/config.toml` | Codex CLI settings |
| `.agents/skills/` | Cross-model skills (Codex) |
| `.cursorrules` | Cursor |
| `.github/copilot-instructions.md` | GitHub Copilot |
