# Working agreements

These come from the owner's project instructions plus rules they stated during the first session (2026-10-24).

## Roles

- The assistant owns the work inside the repo, but does not decide what leaves it.
- The owner reviews all work, then commits and pushes it. The assistant never pushes and does not commit unless explicitly asked.
- Deliver changes as a patch file or as individual files, together with a suggested commit message.

## Teaching

- The owner is new to Lua. For every piece of code, explain what it does, why it was written that way, and how to read it. Walk through unfamiliar syntax and logic.
- Proactively point out flaws in the owner's approach, even when asked to do it their way. The owner's way and the right way are not always the same; use engineering judgment to bring them together.
- Challenging a proposal is welcome. Silently working against the owner's prompting is not: always say so before deviating.

## Written from scratch

- The repo has another branch, `main`, built by humans. Do not read or reference it unless the owner instructs otherwise. Everything on `llm-main` is written from scratch.

## Git conventions

- Working branch: `llm-main`.
- Commit messages are brief: one imperative subject line (example: `Set mod author to Ribboned Ace`), then the trailer `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. Do not add a session link or any other trailer.
- `.agents/` is tracked and must not be gitignored. `.idea/` stays ignored.

## Tooling gotchas (assistant's environment)

- The assistant's clone of the repo is read-only, shallow, and single-branch. It cannot push. Sync it with `git fetch --depth=1 origin llm-main` and compare before producing any patch, so patches apply to the owner's current state.
- To hand over new files in a patch, run `git add -N <path>` first so `git diff` includes them.
- The official docs host `lua-api.factorio.com` refused the assistant's fetch tool on 2026-10-24 (robots rules), including the versioned 2.1.23 pages the owner linked. Do not try to route around this with mirrors or other tools.
- Instead, the owner supplied `runtime-api.json` and `prototype-api.json` (version 2.1.23) as session attachments. They are only available inside that session; in a new session, ask the owner to attach them again before checking the API. Query them with a script and read the gotchas at the top of `research/api-reference-2.1.23.md` (parameter order, blueprint entity variants).
- No Lua interpreter could be installed on 2026-10-25 (`pip install lupa`: no version found; `apt`: no `lua5.2` package; `npm install fengari`: network error). Do not keep retrying. Check code by reading it against the JSON, and a block/bracket balance script; never claim code was run or parsed. Retry only if the owner says the environment changed.
- Deliver code and notes as SEPARATE patches (code patch: only new or changed code files; notes patch: `.agents/` and `.gitignore`), so the owner can commit them separately. Test each applies to the upstream tip on its own.
- Factorio forum threads failed to load for the fetch tool. Mod portal pages and Friday Facts posts on factorio.com did load.
