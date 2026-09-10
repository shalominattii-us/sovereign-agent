# Agents

| Script | Role |
|--------|------|
| `AegentixAutonomousAgent.ps1` | Autonomous agent runtime — includes built-in guardrail smoke tests (critical command, key leak, context poison, loop, social-eng, PII) |
| `AgentsOfChaosMoE.ps1` | Mixture-of-Experts agent swarm with the same security test harness |

Both scripts carry an embedded `SmokeTest` suite. Run the smoke tests after any modification — the harness catches guardrail regressions before deployment.
