# Sandbox and pre-flight

A handoff to an external worker fails in a specific, avoidable way: the worker accepts the brief,
works for a while, then reports that it could not run the project's verification command — because
it never had access to it. Your shell had access. The sandbox the worker runs in does not.

Check first. It is free.

## Check the worker's reach without spending a model call

`codex sandbox` runs any command under the sandbox policy `codex exec` would apply, with no model
in the loop:

```bash
codex sandbox -- <project verification command>                                   # read-only
codex sandbox -c 'sandbox_mode="workspace-write"' -- <project verification command>  # builder
```

Run it from the repository directory (`codex sandbox -C` requires `--permission-profile` on 0.159.2).
`codex sandbox` has no `--ignore-user-config`, so in **isolated** mode (`docs/workers.md`, "Config
modes") give it an empty `CODEX_HOME` — it needs no sign-in — so that it applies the same policy as
an isolated worker:

```bash
mkdir -p .route/codex-home-empty
CODEX_HOME="$PWD/.route/codex-home-empty" codex sandbox -c 'sandbox_mode="workspace-write"' -- <project verification command>
```

Equivalence was checked on 2026-09-30 (0.159.2) with one probe script — write in the repository,
write outside it, write into `.git`, read `/etc/hostname`, fetch `https://example.com` — run both
through this command and through an isolated `codex exec -s workspace-write` worker: identical
results (repository write ok and visible from outside; outside write, `.git` write and network
denied; read ok). In **pinned** mode the plain command is the right one: it reads the same
`config.toml` the worker does.

On a project whose test command shells into containers:

```
$ codex sandbox -- bash -lc 'vendor/bin/sail ps >/dev/null 2>&1; echo "exit=$?"'
exit=1
$ vendor/bin/sail ps >/dev/null 2>&1; echo "exit=$?"
exit=0
```

That is the whole finding, obtained before any brief was written. Probe with a command that needs
the same resources as the tests but ends in seconds (`sail ps`, a database ping, one small test
file) — never the full suite: this probe runs in the foreground, and a suite cut at the Bash tool's
600 s cap leaves orphaned test workers behind. Stage 0 runs it only when a Codex worker will write.

## What the sandbox denies — Sol's inventory from real runs

- **Container runtimes and daemon sockets.** `permission denied while trying to connect to
  /var/run/docker.sock`, `sudo` blocked by `no_new_privileges`. Anything that shells into a container
  (`docker compose`, `podman`, Laravel Sail) fails inside and succeeds outside.
- **The network.** DNS does not resolve: no dependency install, no package fetch, no `ctx7`. Install
  anything new yourself before the handoff.
- **The host process table.** A worker once reported a server as down that was running on the host.
- **Writes outside the workspace** under `workspace-write`; all writes under `read-only` — including,
  once, a read-only `.git` (`Unable to create '.git/index.lock'`). Expect to do the commit yourself.
- **`/tmp` is unreliable.** Three contradictory observations: standalone `codex sandbox` (read-only)
  showed no `/tmp` at all; a `codex exec -s read-only` session saw the directory; critics in August
  could not read briefs placed there ("PLAN.md does not exist"). Never rely on it — briefs, plans and
  outputs live in `.route/` inside the workspace, excluded through the repo's exclude file (`git rev-parse --git-path info/exclude`).

## A sandbox probe can lie by exit code

Inside the sandbox, a write outside the workspace reports success *and reads back as real*:

```
$ codex sandbox -- bash -c 'touch ~/.__probe; echo "exit=$?"; ls -la ~/.__probe'
exit=0
-rw-r--r-- 1 user user 0 Sep  3 11:11 /home/user/.__probe
$ ls -la ~/.__probe            # from outside
ls: cannot access '/home/user/.__probe': No such file or directory
```

The write landed in an overlay that evaporated with the sandbox. On 0.159.2 (2026-09-30) the same
kind of write was denied outright, inside `codex sandbox` and inside an exec worker alike — the
behaviour moves between releases. **Judge a probe by an effect you can observe from outside**, or by
the semantic result of a command that genuinely needs the resource — never by its own exit status.

## Check the runtime, not just the sandbox

`codex doctor --summary` covers whether the worker can start at all: auth mode and provider
reachability (expired logins, quota walls), installed vs. latest version, and a background
`app-server` — the usual cause of a worker that hangs at startup with no output.

## Project-level config can neutralise your flags

A project's `.codex/config.toml` was loaded by every `codex exec` in that directory in the runs
before 3.3, which all read the user config (whether isolated mode still loads it is unverified —
see below). Two things seen in practice:

- `default_permissions = "<profile>"` with a read-only filesystem section — a leftover from an older
  workflow — made the workspace read-only regardless of `-s workspace-write`.
- An MCP server that shells into containers (`command = "vendor/bin/sail"`) cannot start inside the
  sandbox and costs its `startup_timeout_sec` on every run.

Stage 0 reads the file and warns, in both config modes; the fix belongs in the project, not in the
skill. Whether isolated mode still loads it is unverified (`docs/workers.md`, "Config modes"). The
global `$CODEX_HOME/config.toml` is a different matter: its `approvals_reviewer = "auto_review"` is
rung 3 in disguise — on 0.159.2 it alone turns `approval_policy` into `on-request` with automatic
review. Isolated mode does not read that file at all; pinned mode pins `-c approvals_reviewer="user"`
against it.

## The escalation ladder

Climb one rung at a time, only with a failed pre-flight to point at, and say which rung in the
assignment line.

1. **`-s workspace-write`** — the default. Repo writable, network off, no sockets.
2. **Split the work.** The external worker edits only; you run the build, tests and browser checks
   in your own shell and relay results. One relay per fix round, zero extra blast radius. For a
   Gemini worker this is not optional: headless `agy` cancels the run on the first denied command.
3. **Automatic review of escalations** — `-c approvals_reviewer="auto_review"` on every line of that
   worker, exec (with `-s workspace-write`) and resume alike, in either config mode (in pinned mode
   it replaces the `"user"` pin). The worker's escalation requests are reviewed by an automatic
   reviewer under workspace-write, so individual commands can be approved without full access for
   the whole run. You are delegating the approval to a model — say so. Per run, on the command line;
   never through a global config. Verified on 0.159.2: the setting turns `approval_policy` into
   `on-request`, and a network command the sandbox blocked was escalated and approved, on exec and on
   resume. The flag form `--approve-for-me` does the same but implies `workspace-write` and cannot be
   combined with `-s`; resume has no flag form. The assignment line and checkpoint say
   `sandbox=workspace-write, approvals=auto_review (rung 3)`, and the effective-config check expects
   `on-request` / `auto_review`.
4. **`-s danger-full-access`** — the documented escape hatch when the plan truly depends on a
   container runtime. No partial version exists: the granular knobs
   (`sandbox_workspace_write.writable_roots`, `network_access`) cover paths and network, not unix
   sockets — adding `/var/run` to `writable_roots` breaks the sandbox (`bwrap: Can't mkdir /run/.git:
   Permission denied`) rather than opening the socket, and a docker socket is host root anyway. Per
   run, per project, after a failed pre-flight, announced before launch, never in a global config.
   Its session record shows `sandbox_policy: danger-full-access` and `permission_profile: disabled`,
   which is what the effective-config check expects at this rung.

`--dangerously-bypass-approvals-and-sandbox` is not a rung: it also drops approvals and is meant for
hosts that are already sandboxed externally.

## route does not use agy's sandbox — permissions decide

agy 1.2.8 has a `--sandbox` flag ("terminal restrictions"); route does not use it, because its agy
workers run no commands at all and the permission model below is what bounds them.

Antigravity's headless mode denies any tool action that would need a prompt and cancels the turn
(`status:"CANCELED"`, `denied_actions`, exit 0). `--mode plan` for critics, `--mode accept-edits`
for edits-only builders, `--add-dir "$REPO"` so the worker sees the project at all. Workspace trust
(`trustedWorkspaces` in `~/.gemini/antigravity-cli/settings.json`) must cover the repo; the stage-0
`/skills` probe listing zero workspace skills while `.agents/skills/` is populated is the symptom.

## Before the build, regardless of rung

A clean working tree — commit or stash first. A write-mode worker that times out, crashes, hits a
quota or is cancelled leaves valid-looking half-implementations behind, and without a baseline you
cannot tell its work from yours. `.route/` is excluded via the repo's exclude file (`git rev-parse --git-path info/exclude`), so it never dirties
the tree and `git stash -u` leaves it alone; never `git clean -x` in a route checkout.
