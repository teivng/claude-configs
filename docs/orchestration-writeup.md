# Claude Code orchestration: what I learned, what to adopt, what to skip

Written by the orchestrator after running two parallel agent-driven PRs
(survival baselines, compression baselines) and three parallel
research subagents (skills landscape, workflow patterns, hygiene +
multi-agent). The three raw research files are at
`/tmp/research_skills_landscape.md`, `/tmp/research_workflow_patterns.md`,
`/tmp/research_hygiene_multiagent.md` — this document is the filtered
synthesis. **My judgment is mixed in**; not a literature review.

## TL;DR

- The Claude Code skills ecosystem is real but **smaller than its
  marketing**. ~65 audited skills exist, not 66,000. Two installable
  bundles are worth our time: `pr-review-toolkit` (official Anthropic)
  and `obra/superpowers` (worktrees + receiving-code-review).
- **Hooks beat prompts** for behavioral invariants. CLAUDE.md rules get
  dropped under compaction; PreToolUse hooks enforce deterministically.
- The single highest-leverage one-time investment for eval_suite is
  **wiring 2-3 PreToolUse hooks** for the rules we keep restating
  ("don't hardcode `/home/ubuntu/`", "no loose files at repo root").
  ~30 min of work; deterministic enforcement after.
- **Most "best practices" content is shallow**. Anthropic's docs +
  Simon Willison's blog + a handful of detailed engineer posts carry
  90 % of the signal. The HN comment volume is mostly hot takes.
- This session's own orchestration produced some real lessons that
  cross-validate the research findings (and contradict some popular
  advice). Captured at the bottom.

---

## 1. Three highest-leverage tactics to adopt this week

### 1.1 Install + test two skill bundles

```bash
/plugin install pr-review-toolkit@claude-plugins-official
/plugin install superpowers@obra-superpowers
```

**`pr-review-toolkit`** ships six review agents; the two that matter
for us:

- **`silent-failure-hunter`** — catches swallowed exceptions, empty
  `except` blocks, and "return None on error" patterns. The `score_trial`
  rewire and the compression `y`-threading in PR #10 are both surface
  areas where silent failures would be plausible.
- **`pr-test-analyzer`** — checks whether new pipeline components have
  test coverage. Would have automatically flagged any of the new
  `Compression` subclasses if Agent 1 had forgotten to test them.

**`obra/superpowers`** ships `using-git-worktrees`, `finishing-a-development-branch`,
and `receiving-code-review`. The first two are what we did by hand
this session (worktree-per-agent, structured merge decisions); the
skill enforces the same discipline going in/out. **`receiving-code-review`**
enforces VERIFY → EVALUATE → IMPLEMENT one item at a time, which
maps directly to the "build, don't patch" / "no proliferation"
feedback patterns already in `feedback_*` memory files.

**Test plan: use these on PRs #9 and #10 before merge.** That's the
empirical evaluation — does either skill catch something I'd want to
catch? Whichever does, keep; the other, uninstall.

### 1.2 Wire 2-3 PreToolUse hooks for the most-violated CLAUDE.md rules

The research converged on this: CLAUDE.md rules disappear under
compaction. Hooks survive forever. Three deterministic checks
worth wiring:

```yaml
# .claude/settings.json (sketch)
PreToolUse:
  - matcher: Write
    name: block-root-loose-files
    command: |
      jq -r .tool_input.file_path
        | grep -E '^(test_|debug_|scratch_|adhoc_)' && exit 2 || exit 0
  - matcher: Write|Edit
    name: block-hardcoded-home
    command: |
      jq -r .tool_input.new_string
        | grep -E '^/home/ubuntu/' && exit 2 || exit 0
PostStop:
  - name: warn-untracked-large-artifacts
    command: |
      git status --porcelain
        | awk '/^\?\?/ && /\.(npy|pt|h5|h5ad|pkl|log)$/ { print "WARN untracked artifact: " $2 }'
```

Time: ~30 min including a smoke test. Payoff: every "you put a loose
file at repo root again" lecture I've given Claude this session
becomes a deterministic exit-2.

### 1.3 Add a compaction-preservation stanza to CLAUDE.md

Anthropic's own docs (and the sigalovskinick gist that the hygiene
research highlighted) both confirm: compaction drops decisions and
early-session conventions first. Add a literal section to
`CLAUDE.md`:

```markdown
## Compaction preservation

When compacting, **always preserve**:
- The list of modified files and which branch they're on
- `paths.py` conventions (every external path goes through there)
- Compression is a sweep axis; the embedder NEVER mean-pools
- Embedder `.name` strings are cache keys — bump on weight/shape change
- Any explicit "rejected alternative" decision documented in memory
- The git remote rule: do not push without asking
```

Free, no install, survives context refresh. Combine with manual
`/compact` at task boundaries instead of waiting for auto-trigger.

---

## 2. Skills inventory (filtered to relevant)

### Worth installing

| Skill | Source | Why |
|---|---|---|
| `pr-review-toolkit` | `claude-plugins-official` | Six lens-based review agents; CLAUDE.md-aware |
| `using-git-worktrees` | `obra/superpowers` | Codifies the pattern we used by hand this session |
| `finishing-a-development-branch` | `obra/superpowers` | Structured merge/PR/discard decisions |
| `receiving-code-review` | `obra/superpowers` | VERIFY → EVALUATE → IMPLEMENT one at a time |
| **Brain Dump skill + PreCompact/PostCompact hooks** | sigalovskinick gist | Compaction Memory pattern — documented 12+ cycles with full retention vs. coherence loss after 2-3 without |

The Brain Dump pattern is the most interesting find of the research.
It's a single skill + two hooks; setup is ~1 hour. **I'd validate
empirically before committing** — install on a throwaway branch, run
a multi-hour session, observe.

### Worth knowing about, probably skip

- The 35-skill `claude-plugins-official` bundle has lots of variety
  but most are domain-specific (frontend, mobile, Rust). Cherry-pick
  individual skills as needed.
- `obra/superpowers` has a `using-skills-effectively` skill that's
  primarily about its own ecosystem; useful as a recipe-book but not
  a runtime tool.
- Various `claude-debug` and `claude-explain` skills are theatrical —
  they basically re-prompt with different wording. The first-party
  `simplify` and `review` skills built into Claude Code installs do
  similar things more cleanly.

### "65k skills" — ignore

The SkillsMP marketplace lists ~66,000 entries; nearly all are GitHub
scrapes with zero curation, broken installs, or skill-flavored prompts
from someone's blog. Audited ecosystem is dozens to low hundreds.

---

## 3. CLAUDE.md / hooks updates I'd recommend for eval_suite

In rough priority order:

1. **Add the compaction-preservation stanza** (above) to CLAUDE.md.
2. **Surface the critical behavioral rules in a `## Do NOT` block** at the top of CLAUDE.md, in MUST-NOT language rather than buried in architecture prose. Specifically:
   - MUST NOT mean-pool inside the embedder
   - MUST NOT push to `origin` without explicit user authorization
   - MUST NOT modify test files without explicit instruction (this is the workflow-patterns research's #1 failure mode — applies to us)
   - MUST NOT hardcode `/home/ubuntu/...` in module code
   - MUST NOT add fields to `paths.py` or `PipelineConfig` without first checking existing conventions
3. **Wire the 2-3 PreToolUse hooks** described in 1.2.
4. **Add a `/.claude/session-handoff.md` convention** updated at session boundaries: Status / Modified files / Decisions made / Blocked on / Next. Eliminates the context-reconstruction overhead that bit us today (I had stale assumptions about the `survival/` file layout).
5. **PostStop hook to warn on untracked large artifacts** (`*.npy`, `*.pt`, etc. outside the cache dirs). Saves us from accidentally committing a 12 GB embedding cache.

---

## 4. What I'd push back on / skip

- **"Always use subagents for parallel work."** Two of our subagents
  ran into session-completion issues this session (Agent 1 hit GPU
  contention from the parallel survival sweep, Agent 2 had a polling
  exit). When the work is genuinely sequential or shares state, one
  long agent in `EnterWorktree` mode is cleaner than two parallel.
- **"Manual `/compact` at 60% context".** Sounds great until you
  realize an agent in mid-flight can't see its own context
  percentage. Useful for the human-driver. Less useful for
  subagents. The compaction-preservation stanza is the more
  reliable lever.
- **The "Compactor + Watcher + Closer" pattern I built earlier this
  session.** Over-engineered. Agents that finish their own work
  (Agent 2 did, on a second-chance return) don't need a separate
  closer. Reserve the pattern for actual agent failure recovery,
  not as a default.
- **Vendoring heavy deps** (pycox, torchtuples). Required deps with
  pinned versions worked fine; vendoring is over-engineering until
  there's a real upgrade-breakage incident.
- **"Big CLAUDE.md is good, more rules better."** The workflow-
  patterns research's #2 failure mode is CLAUDE.md bloat causing
  instruction dropout. Our CLAUDE.md is already dense; new rules
  should mostly go to hooks (deterministic) or memory files
  (lazily-loaded), not into CLAUDE.md.

---

## 5. Lessons from this session itself

These aren't from the research — they're from watching the system
work and break in real time. They cross-validate or contradict the
research findings:

1. **Agents that build durable on-disk artifacts (worktree, plan
   file, results JSON) are recoverable; agents that build only
   session state are not.** Agent 2 looked dead, then came back
   alive on a second-chance return and completed its own PR. The
   only reason recovery was even possible was because the actionable
   intermediate state was on disk, not in conversation memory.
2. **The "Don't push without asking" CLAUDE.md rule fired a false
   positive on Agent 1.** Viet authorized the push when he said
   "go ahead fire away" before I spawned the agent; the agent's
   harness saw the literal string match and warned. **Rules need
   nuance about pre-authorization scope**; this is something to
   add to the Do NOT block in section 3.
3. **Parallel pipelines on a shared GPU/CPU host inflate wall
   times 2-4×.** Agent 1's sweep ran ~41 min in part because
   Agent 2's pipeline was eating CPU. Schedule agent-spawned
   compute serially unless the runs are genuinely lightweight.
4. **Closing-out is the failure-prone step.** Both agents nailed the
   implementation. Both stumbled at "now write the markdown, commit,
   PR" because that requires watching a long background process
   and resuming. The fix is a tighter "closing protocol" in the
   prompt, not a separate closer agent.
5. **Research subagents are great at enumeration, mediocre at
   judgment.** All three returned good link-dumps and summaries.
   None of them said "the marketplace's 66k number is bullshit"
   without prompting; they had to be explicitly told to mark
   confidence. **Judgment stays with the orchestrator.**

---

## 6. Open / revisit in 3 months

- Does the Compaction Memory pattern survive an actual multi-week
  eval_suite project? Install, use, evaluate.
- Does `pr-review-toolkit` catch anything `simplify` + `review`
  (the built-in skills) don't? Run all three on PR #9 and #10 and
  diff their outputs.
- Is there a missing skill for "detect a duplicate abstraction
  added by parallel agents" — i.e., two worktrees both adding a
  `_run_prognostic_cv` helper? The research found no such tool. If
  the gap is real, build one.
- Revisit the "Writer/Reviewer split-session" pattern (a fresh
  Claude session reviews a diff before merge). The literature says
  it works; we haven't tested it on eval_suite.

---

## What I'd actually do next (concrete)

1. Review PRs #9 and #10 myself, using whichever combination of
   first-party `review` / `security-review` / `simplify` skills is
   currently available. That's the empirical PR-review baseline.
2. Install `pr-review-toolkit` and run it on the same two PRs.
   Compare what it catches vs. what the baseline skills caught.
   Keep whichever subset is genuinely useful.
3. Wire the 2-3 PreToolUse hooks from section 1.2.
4. Update CLAUDE.md with the compaction-preservation stanza and the
   `## Do NOT` block.
5. Stop there for now. Don't install the full `superpowers` bundle
   until I have a concrete failure mode it would have prevented.

Less is more on skills; more is more on hooks.
