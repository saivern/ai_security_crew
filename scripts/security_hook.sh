#!/bin/bash
# Fires on every Claude Code UserPromptSubmit event.
# Detects feature-building intent and routes to MCP (primary),
# Python SecurityAssessment (fallback), or inline OWASP reminders.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('prompt',''))" 2>/dev/null || echo "")
PROMPT_LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')
WORD_COUNT=$(echo "$PROMPT" | wc -w | tr -d ' ')

# --- Detection ---

[ "$WORD_COUNT" -lt 8 ] && exit 0

echo "$PROMPT_LOWER" | grep -qE "\bsecurity\b" && exit 0

echo "$PROMPT_LOWER" | grep -qE "\b(explain|what is|how does|show me|why|review|document|documentation|docs|comment|refactor|rename|format|lint|clean)\b" && exit 0

echo "$PROMPT_LOWER" | grep -qE "\b(build|implement|create|add|develop|integrate|write|make|scaffold|set up)\b" || exit 0

HAS_TECH=$(echo "$PROMPT_LOWER" | grep -cE "\b(api|endpoint|route|auth|authentication|database|service|component|function|module|integration|jwt|oauth|login|upload|payment|user|token|cache|queue|webhook|feature|flow|system|backend|frontend)\b" || true)
[ "$HAS_TECH" -eq 0 ] && [ "$WORD_COUNT" -le 15 ] && exit 0

# --- Routing ---

# State 1: MCP server running — instruct Claude to call MCP tool
if docker ps --filter "ancestor=mcp-security-review:latest" --format "{{.ID}}" 2>/dev/null | grep -q .; then
  cat <<EOF
⚠️  AI SECURITY CREW — SECURITY REVIEW REQUIRED ⚠️

A feature-building task was detected. You MUST call the lightweight_security_review
MCP tool before writing any code.

Tool: lightweight_security_review
Task: "$PROMPT"

Apply ALL returned security requirements, guidelines, and checklist items to every
line of code you generate. Do not skip this step. Do not write code first.
EOF
  exit 0
fi

# State 2: MCP not running — try Python SecurityAssessment standalone
if cd "$REPO_DIR" && uv run python -c "from mcp_security_review.security import SecurityAssessment" 2>/dev/null; then
  echo ""
  echo "⚠️  AI SECURITY CREW — SECURITY REVIEW (Standalone Mode) ⚠️"
  echo ""
  cd "$REPO_DIR" && uv run python scripts/security_hook_runner.py "$PROMPT"
  echo ""
  echo "ℹ️  MCP server not detected. For full integration (Jira, Confluence, CVE scanning):"
  echo "   cd $REPO_DIR && docker build -t mcp-security-review:latest . && see README for MCP config"
  exit 0
fi

# State 3: Nothing available — inline OWASP reminders + setup guidance
cat <<EOF
⚠️  AI SECURITY CREW — SECURITY REMINDER ⚠️

A feature-building task was detected. Apply these principles to all generated code:

- Validate and sanitize ALL user input server-side
- Use parameterized queries — never string-concatenate SQL
- Hash passwords with bcrypt or argon2 (never MD5/SHA1)
- Never hardcode secrets — use environment variables
- Apply authentication and authorization checks on every sensitive operation
- Return generic error messages — never expose stack traces
- Use HTTPS, set HttpOnly + SameSite cookies for session tokens

ℹ️  For full automated security reviews, set up AI Security Crew:
   cd $REPO_DIR && uv sync && bash scripts/setup_claude_hook.sh
EOF
