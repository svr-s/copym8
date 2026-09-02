# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.2] - 2026-09-02
### Added
- Monorepo structural overhaul to support multiple native platforms under a unified ecosystem.
- Cross-platform root README.md with clear structural explanations and website links.
- Contributing and Code of Conduct guidelines for open-source community engagement.

### Changed
- Standardized macOS and root repository taglines to emphasize platform-agnostic cloud synchronization.
- Removed legacy Ruby scaffolding scripts used during initial setup.
- Vastly improved readability of the macOS platform features list.

### Fixed
- Hardened background I/O operations and strict memory-limit eviction constraints to prevent OOM panics under heavy load.
