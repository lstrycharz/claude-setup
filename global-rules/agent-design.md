# AI-Agent / LLM-Pipeline Project Design

## When to apply this rule
Apply when the project is an AI agent or LLM pipeline that will be **shipped or iterated over time**. Skip for one-shot prompts, demos, or any LLM call living inside a feature that isn't itself an agent.

## The framework
Three **separable** layers — *not* a single stack to adopt all at once:

1. **Decomposition** — split the agent's job into inspectable, testable, individually-improvable pieces.
2. **Evaluation discipline** — prove it works, catch regressions before they ship, keep judges calibrated.
3. **Self-improvement** — the system learns from its own track record and (optionally) proposes its own changes.

Apply in order — never skip 1 or 2 to reach 3. Most projects need 1, many need 1+2, few need all three.

Full playbook: `~/.claude/playbooks/AGENT_PROJECT_PLAYBOOK.md`. **Walk it during plan mode** at agent project kickoff — decide which layers apply, record "n/a, because…" for any you skip.

## Non-negotiables per layer

**Layer 1 (every agent project):**
- 5–9 stages, each a **deep module** — one public interface, complexity hidden inside (prompt + strict output contract + model + own evaluators).
- **Per-stage model routing is correctness, not cost** — sometimes the weaker/faster model is the right one (e.g. avoiding over-reasoning on a creative-realism task).
- **Tools are the boundary** to the outside world; never tangled with reasoning code.
- **Strict output contracts** (Pydantic / Zod / equivalent). Malformed output fails loudly and immediately.
- Cost cap + retry cap threaded through every stage.

**Layer 2 (when shipping or iterating):**
- Each stage owns its evaluators. **Blocking** (force a re-run) vs **advisory** (log only) is a real, useful distinction.
- **Cassette-replay regression** on every PR via CI gate. Deterministic, $0, runs in seconds.
- ~10% human-review sample to keep AI judges calibrated against humans.
- Read-only dashboard over a single append-only log.
- If tests cost real money or run in minutes, fix that first.

**Layer 3 (apply only if scope genuinely justifies it):**
- Any self-improving system **will cheat** if not boxed in. The reward-hacking defense is **core, not polish**.
- The optimizer must be:
  - limited to a **deny-by-default edit surface**;
  - **blind to the rubric prose** of the judges it optimizes against (anti-Goodhart);
  - gated by ≥6 independent guards run from a **trusted copy** of themselves (base ref, never the PR head);
  - **read-only** on the eval DB;
  - **PR-write only** (no merge token; humans are the final gate).
- **No statistical theater** — report n, delta, effect size; say "underpowered" explicitly. 20 runs/week can't support a t-test.
- The **autoresearch lesson** (Karpathy): lock down the metric, the data, and the scope — let only the agent's reasoning vary.

## Portable patterns (worth taking outside agent projects too)
- Deep modules > shallow.
- Structured outputs > regex parsing.
- Cassette-replay tests > live API in CI.
- Advisory vs blocking distinction in any quality-check system.
- No statistical theater — flag "underpowered" when it is.
