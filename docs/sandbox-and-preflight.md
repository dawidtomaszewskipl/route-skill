# Sandbox and pre-flight

A handoff to an external worker fails in a specific, avoidable way: the worker
accepts the brief, works for a while, then reports that it could not run the
project's own verification command — because it never had access to it. Your
shell had access. The sandbox the worker runs in does not.

Check first. It is free.

## Check the worker's reach without spending a model call

`codex sandbox` runs any command under the same sandbox policy `codex exec`
would apply, with no model in the loop:

```bash
# the critic's world
codex sandbox -- <project verification command>

# the builder's world
codex sandbox -c 'sandbox_mode="workspace-write"' -- <project verification command>
```

Run it with whatever the plan will ask the worker to run — the test command, the
build, the container wrapper — and compare against the same command in your own
shell.

A worked example, on a project whose test command shells into containers:

```
$ codex sandbox -- bash -lc 'vendor/bin/sail ps >/dev/null 2>&1; echo "exit=$?"'
exit=1
$ vendor/bin/sail ps >/dev/null 2>&1; echo "exit=$?"
exit=0
```

That is the entire finding, obtained before any brief was written: this worker
cannot verify its own work on this project.

## What the sandbox actually denies

Verified, not assumed:

**Container runtimes and other daemon sockets.** Anything that shells into a
container — `docker compose`, `podman`, framework wrappers like Laravel Sail —
fails inside and succeeds outside. This is the failure that bites most often,
because the command looks local.

**The network.** DNS does not resolve inside the sandbox:

```
$ codex sandbox -- bash -lc 'curl -sS -m 8 -o /dev/null https://example.com \
    && echo "network OK" || echo "network BLOCKED"'
curl: (6) Could not resolve host: example.com
network BLOCKED
```

So: no dependency install, no package fetch, no API call. Plan the build around
an already-installed tree, and install anything new yourself before the handoff.

**Writes outside the workspace** under `workspace-write`; all writes under the
default `read-only` policy.

## A sandbox probe can lie by exit code

This one is worth internalising. Inside the sandbox, a write outside the
workspace reports success *and reads back as real*:

```
$ codex sandbox -- bash -c 'touch ~/.__probe; echo "exit=$?"; ls -la ~/.__probe'
exit=0
-rw-r--r-- 1 user user 0 Sep  3 11:11 /home/user/.__probe

$ ls -la ~/.__probe                      # from outside the sandbox
ls: cannot access '/home/user/.__probe': No such file or directory
```

The write lands in an overlay that evaporates with the sandbox. Both the exit
code and a following `ls` in the same sandboxed shell agree it worked; the host
disagrees.

The rule that follows: **judge a probe by an effect you can observe from outside
the sandbox**, or by the semantic result of a command that genuinely needs the
resource (`sail ps` returning 1, DNS failing). Never by the probe's own exit
status alone.

## Check the runtime, not just the sandbox

`codex doctor` covers the other half — whether the worker can start at all:

- auth mode and provider reachability (catches expired logins and quota walls);
- installed vs. latest version;
- whether a background `app-server` is running, which is the usual cause of a
  worker that hangs at startup with no output.

Add `--json` for a machine-readable, redacted report.

## The escalation ladder

Climb one rung at a time, and only with a failed pre-flight to point at.

### 1. `-s workspace-write` — the default

Repo writable, network off, no daemon sockets. Never leave this rung on a hunch.

### 2. Split the work

The external worker edits only; **you** run the build, the tests and any browser
checks in your own shell, then relay results back. Costs one relay per fix round.
Costs nothing in blast radius. This is the right answer whenever the user would
rather not widen the sandbox, and it works for every project regardless of how
its verification is wired.

### 3. `--approve-for-me`

Escalation requests from the worker are routed through an automatic reviewer
under the workspace-write sandbox, so individual commands can be approved without
the run holding full access throughout. Genuinely narrower than full access — but
you are delegating the approval decision to a model, so put it in the assignment
line rather than adding it quietly.

### 4. `-s danger-full-access`

The documented escape hatch when the plan truly depends on a container runtime.

There is no partial version of this rung. The granular knobs
(`sandbox_workspace_write.writable_roots`, `network_access`) cover writable paths
and network access, not unix sockets — adding `/var/run` to `writable_roots`
breaks the sandbox rather than opening the socket. And access to a docker socket
is effectively host root anyway, so a narrower allowance would not be meaningfully
safer. The choice is binary: the worker stays out of the container runtime, or it
gets the machine.

Therefore:

- escalate **per run, per project**, never in a global config where it leaks into
  every project you touch;
- escalate only **after** a failed pre-flight;
- **say so in the assignment line**, so the user can veto before the worker
  starts.

`--dangerously-bypass-approvals-and-sandbox` is not this rung. It also drops
approvals and is meant for hosts that are already sandboxed externally.

## Before the build, regardless of rung

Require a clean working tree — commit or stash first. A write-mode worker that
times out, crashes or is cancelled leaves valid-looking half-implementations
behind, and without a clean baseline you cannot tell its work from yours.
