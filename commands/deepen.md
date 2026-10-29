---
description: Rewrite a task brief the way a top professional in that field would approach it, before starting
argument-hint: [the task, or leave empty to use the last request]
disable-model-invocation: true
---

Before doing the task below (or my last request, if none is given), answer four questions in a few lines each:

1. What would a top professional in this field do here that I am not asking for?
2. What is the rawest material they would start from (raw exports, logs, the actual data), rather than a summary of it?
3. Which methods and tools would they use? Name the real ones, not a role description.
4. What evidence, other than your own judgment, would show the result is right? Prefer something runnable: a reconciliation script, a test, a benchmark, a primary source.

Then rewrite my brief to ask for exactly that: the outcome behind the task, the raw inputs, the methods, and the outside check as the definition of done. Show the rewritten brief and wait for my go-ahead before executing, because the point is to change what gets built.

Task: $ARGUMENTS
