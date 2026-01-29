# KSwitch Tasks

Tasks are executable shell scripts that can be run from KSwitch menu bar and main window.
The tasks can accept inputs, and they provide interactive output in the app.

## Tasks Directory

By default, KSwitch looks for tasks in `~/.kswitch/tasks/`. You can configure a custom location in Settings.

The directory can also be a symlink, allowing you to store scripts elsewhere (e.g., in a git repository):

```bash
mkdir -p ~/.kswitch
ln -s /path/to/your/scripts ~/.kswitch/tasks
```

## Script Requirements

1. Must be named with the `.kswitch.sh` suffix (e.g., `my-task.kswitch.sh`)
2. Must be executable (`chmod +x my-task.kswitch.sh`)
3. Should have a shebang (e.g., `#!/usr/bin/env bash` or `#!/bin/zsh`)
4. Use `set -euo pipefail` for proper error handling

## Naming Convention

You can set a custom display name and description using comments inside the script:

```bash
# KSWITCH_TASK: My Custom Task Name
# KSWITCH_TASK_DESC: A description shown in the task details view.
```

If not specified, the display name is derived from the filename:
- `aws-sso-login.kswitch.sh` → "aws sso login"
- `flux_reconcile_ks.kswitch.sh` → "flux reconcile ks"

## Inputs

Define inputs in comment headers within the first 100 lines of the script.

### Required Inputs

```bash
# KSWITCH_INPUT: VAR_NAME "Description of the input"
```

Running a task from the menu bar that contains required inputs, will
make KSwitch open the main window to prompt for the necessary values.

### Optional Inputs

```bash
# KSWITCH_INPUT_OPT: VAR_NAME "Description of the input (default: some-default)"
```

The script should handle optional inputs by providing defaults,
typically using bash parameter expansion.

Running a task from the menu bar that contains only optional inputs will
not prompt for any values before execution.

## Environment

Scripts run with:
- `TERM=xterm-256color` for color support
- Working directory set to the script's directory
- Full PTY emulation for interactive output

## Example

A complete task script that reconciles a Flux Kustomization:

```bash
#!/usr/bin/env bash
set -euo pipefail

# KSWITCH_TASK: flux reconcile ks
# KSWITCH_TASK_DESC: Reconcile a Flux Kustomization using the flux CLI.

# Inputs

# KSWITCH_INPUT: NAME "Resource name"
NAME="${NAME:?NAME is required}"

# KSWITCH_INPUT_OPT: NAMESPACE "Target namespace (default: flux-system)"
NAMESPACE="${NAMESPACE:-flux-system}"

# Commands

flux reconcile ks "${NAME}" -n "${NAMESPACE}" --with-source
```

For more examples, see the [.kswitch/tasks dir](https://github.com/stefanprodan/kswitch/tree/main/.kswitch/tasks)
in the KSwitch repository.
