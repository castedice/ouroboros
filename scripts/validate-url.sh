#!/bin/bash
# Layer 2: WebFetch URL validation hook
# Blocks dangerous URLs: non-HTTPS protocols, internal IPs, direct IP access
# Part of ouroboros 4-layer security design
#
# Coverage boundary — NOT protected against:
#   - DNS rebinding (domain resolves to internal IP after validation)
#   - HTTP redirect chains to internal addresses (post-fetch)
#   - IPv6 beyond link-local (fe80:) — e.g., unique local (fd00::/8)
#   - URL encoding/obfuscation bypasses (e.g., %31%32%37.0.0.1)
#   - TOCTOU between this check and actual fetch
# These require runtime/network-level mitigations outside hook scope.

INPUT=$(cat)
URL=$(echo "$INPUT" | jq -r '.tool_input.url // empty')

# No URL — skip validation
if [ "$URL" = "" ]; then
  exit 0
fi

# Block dangerous protocols (file://, ftp://, data://, javascript:)
# HTTP is allowed — Claude Code auto-upgrades to HTTPS
if echo "$URL" | grep -qiE '^(file|ftp|data|javascript):'; then
  echo "Blocked: Only HTTP/HTTPS URLs are allowed" >&2
  exit 2
fi

# Extract hostname
HOST=$(echo "$URL" | sed -E 's|^https?://||' | sed -E 's|[:/].*||' | tr '[:upper:]' '[:lower:]')

# Block internal/private addresses (SSRF prevention)
if echo "$HOST" | grep -qE '^(localhost|127\.|10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.|0\.|169\.254\.|::1|fe80:)'; then
  echo "Blocked: Internal/private addresses are not allowed" >&2
  exit 2
fi

# Block direct IP addresses — force domain names for auditability
if echo "$HOST" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "Blocked: Direct IP addresses are not allowed. Use domain names" >&2
  exit 2
fi

exit 0
