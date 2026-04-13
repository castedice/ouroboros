# Security Review Checklist

Use this reference for the Security Review procedure and for Safety-perspective reviews that need explicit security coverage.
The required baseline is dependency audit, secret detection, and license compliance.

## Dependency Audit

- Identify every dependency manifest and lock file that governs shipped code.
- Run available audit tooling such as `npm audit`, `cargo audit`, `pip-audit`, or `govulncheck` when the environment supports it.
- If no audit tool is available, inspect locked versions and flag packages with known vulnerable or deprecated ranges.
- Record the package name, version, CVE or advisory identifier, severity, and the minimal safe upgrade when available.
- Treat exploitable or high-severity advisories as `P1` when they affect shipped paths.
- Treat moderate advisories, deprecated packages with known issues, or incomplete upgrade paths as `P2`.
- Treat stale but not known-vulnerable dependencies as `P3` unless the caller asked for dependency hygiene work.

## Secret Detection

- Search for hardcoded passwords, tokens, API keys, private keys, and connection strings in code and config.
- Check for URLs that embed credentials such as `://user:pass@`.
- Verify that secrets come from environment variables, secret managers, or deployment config instead of committed literals.
- Check `.gitignore` for patterns such as `.env`, `*.pem`, `*.key`, and other sensitive local files.
- Treat committed secrets or private keys as `P1`.
- Treat unsafe secret-handling patterns, partial credential exposure, or missing ignore hygiene around likely secret files as `P2`.
- Treat non-sensitive placeholder cleanup or speculative hygiene gaps as `P3`.

## License Compliance

- Read license declarations from manifests, lock files, and vendored dependencies when available.
- Flag unknown or missing license metadata on key dependencies.
- Flag copyleft licenses such as GPL or AGPL when the project context suggests proprietary or incompatible distribution.
- Note the overall license mix when the caller needs compliance visibility rather than isolated findings.
- Treat a missing or incompatible license on a critical shipped dependency as `P1` when distribution would be blocked.
- Treat copyleft risk or unresolved license ambiguity as `P2`.
- Treat documentation gaps or cleanup-only metadata issues as `P3`.

## Optional Code-Level Security Spot-Check

- Add code-level security checks when the caller expects a broader security pass or when the changed path touches untrusted input, auth, or filesystem boundaries.
- Look for injection, path traversal, insecure deserialization, weak authorization checks, unsafe shell invocation, and comparable OWASP-style issues.
- Escalate code-level issues through the same `P1` to `P3` ladder, but do not skip the baseline dependency, secret, and license checks.
