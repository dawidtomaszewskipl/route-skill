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

On a project whose test command shells into containers:

```
$ codex sandbox -- bash -lc 'vendor/bin/sail ps >/dev/null 2>&1; echo "exit=$?"'
exit=1
$ vendor/bin/sail ps >/dev/null 2>&1; echo "exit=$?"
exit=0
```

That is the whole finding, obtained before any brief was written.

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
  outputs live in `.route/` inside the workspace, excluded through `.git/info/exclude`.

## A sandbox probe can lie by exit code

Inside the sandbox, a write outside the workspace reports success *and reads back as real*:

```
$ codex sandbox -- bash -c 'touch ~/.__probe; echo "exit=$?"; ls -la ~/.__probe'
exit=0
-rw-r--r-- 1 user user 0 Sep  3 11:11 /home/user/.__probe
$ ls -la ~/.__probe            # from outside
ls: cannot access '/home/user/.__probe': No such file or directory
```

The write landed in an overlay that evaporated with the sandbox. **Judge a probe by an effect you
can observe from outside**, or by the semantic result of a command that genuinely needs the
resource — never by its own exit status.

## Check the runtime, not just the sandbox

`codex doctor --summary` covers whether the worker can start at all: auth mode and provider
reachability (expired logins, quota walls), installed vs. latest version, and a background
`app-server` — the usual cause of a worker that hangs at startup with no output.

## Project-level config can neutralise your flags

A project's `.codex/config.toml` is loaded by every `codex exec` in that directory. Two things seen
in practice:

- `default_permissions = "<profile>"` with a read-only filesystem section — a leftover from an older
  workflow — made the workspace read-only regardless of `-s workspace-write`.
- An MCP server that shells into containers (`command = "vendor/bin/sail"`) cannot start inside the
  sandbox and costs its `startup_timeout_sec` on every run.

Stage 0 reads the file and warns; the fix belongs in the project, not in the skill.

## The escalation ladder

Climb one rung at a time, only with a failed pre-flight to point at, and say which rung in the
assignment line.

1. **`-s workspace-write`** — the default. Repo writable, network off, no sockets.
2. **Split the work.** The external worker edits only; you run the build, tests and browser checks
   in your own shell and relay results. One relay per fix round, zero extra blast radius. For a
   Gemini worker this is not optional: headless `agy` cancels the run on the first denied command.
3. **`--approve-for-me`** — the worker's escalation requests are reviewed by an automatic reviewer
   under workspace-write, so individual commands can be approved without full access for the whole
   run. You are delegating the approval to a model — say so.
4. **`-s danger-full-access`** — the documented escape hatch when the plan truly depends on a
   container runtime. No partial version exists: the granular knobs
   (`sandbox_workspace_write.writable_roots`, `network_access`) cover paths and network, not unix
   sockets — adding `/var/run` to `writable_roots` breaks the sandbox (`bwrap: Can't mkdir /run/.git:
   Permission denied`) rather than opening the socket, and a docker socket is host root anyway. Per
   run, per project, after a failed pre-flight, announced before launch, never in a global config.

`--dangerously-bypass-approvals-and-sandbox` is not a rung: it also drops approvals and is meant for
hosts that are already sandboxed externally.

## agy has no sandbox — it has permissions

Antigravity's headless mode denies any tool action that would need a prompt and cancels the turn
(`status:"CANCELED"`, `denied_actions`, exit 0). `--mode plan` for critics, `--mode accept-edits`
for edits-only builders, `--add-dir "$REPO"` so the worker sees the project at all. Workspace trust
(`trustedWorkspaces` in `~/.gemini/antigravity-cli/settings.json`) must cover the repo; the stage-0
`/skills` probe listing zero workspace skills while `.agents/skills/` is populated is the symptom.

## Before the build, regardless of rung

A clean working tree — commit or stash first. A write-mode worker that times out, crashes, hits a
quota or is cancelled leaves valid-looking half-implementations behind, and without a baseline you
cannot tell its work from yours. `.route/` is excluded via `.git/info/exclude`, so it never dirties
the tree and `git stash -u` leaves it alone; never `git clean -x` in a route checkout.
