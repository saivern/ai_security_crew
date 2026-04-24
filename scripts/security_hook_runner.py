#!/usr/bin/env python3
"""Standalone runner for SecurityAssessment — called by security_hook.sh (State 2)."""
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

from mcp_security_review.security import SecurityAssessment

prompt = " ".join(sys.argv[1:]) if len(sys.argv) > 1 else ""
if not prompt:
    sys.exit(0)

assessment = SecurityAssessment()
requirements = assessment.assess_ticket({
    "summary": prompt,
    "description": prompt,
    "fields": {"issuetype": {"name": "Story"}, "labels": []},
    "comments": [],
})

print(f"Risk Level   : {requirements.risk_level}")
print(f"Categories   : {', '.join(requirements.security_categories)}")
print()
print(requirements.prompt_injection)
print()
print("Apply ALL requirements above to every line of code you generate. This is mandatory.")
