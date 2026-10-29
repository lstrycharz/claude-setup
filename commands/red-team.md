---
description: Attack a finished deliverable with independent critics, then have a separate judge decide which findings are real
argument-hint: [file or artifact to review] [optional: what it must convince the reader of]
disable-model-invocation: true
---

Red-team the deliverable named here: $ARGUMENTS

The session that produced a piece of work is a poor judge of it, so none of the review happens in this context.

1. **Critics.** Spawn three subagents in parallel, each with a fresh context and only the deliverable plus its source data. Give each one a single attack:
   - **Facts and numbers:** recompute every figure from the source data; flag any that don't reconcile, any denominator or time-base mismatch, and any claim with no source.
   - **Reasoning:** find the weakest causal claim, the strongest counterargument, and anything stated as fact that is actually inferred.
   - **Reader:** read it as the stated audience (default: a skeptical executive with 5 minutes); flag what they'd misread, what's missing for a decision, and what they'd push back on.
   Each critic returns findings with location and evidence, ranked by severity.
2. **Judge.** Spawn one more fresh subagent with the deliverable, the source data and all critic findings. Its only job is to rule each finding valid, partly valid or invalid, with a one-line reason, and to attach a proposed fix to each valid one. Invalid findings are dropped.
3. **Report.** Show me the judge's valid findings, most severe first, with its proposed fixes — don't add your own, because this session wrote the work. Do not edit the deliverable until I say which fixes to apply.

Use this for boss-facing or client-facing work only: four fresh-context subagents each re-read the deliverable and its sources, so expect several times the cost of `/code-review`.
