# Robotics Actions Workflows

This repository hosts a collection of [reusable workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows) for building, testing & releasing snaps.

These workflows are intended to be re-used in github actions building snaps.
They implement an opinionated workflow to build, test & release snaps.

## Quick start

Here is an example of setting up a workflow:

```yaml
on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main
  workflow_dispatch:

jobs:
  snap:
    uses: canonical/robotics-actions-workflows/.github/workflows/snap.yaml@main
      secrets:
        snapstore-login: ${{ secrets.SNAPSTORE_LOGIN }}
```

## Examples

Examples of this reusable workflow can be found at [`canonical/robotics-action-workflows-tests`](https://github.com/canonical/robotics-action-workflows-tests/tree/main/.github/workflows).

## Details

This repository contains several reusable workflows to automate the release of snaps.

The reusable workflows are:

- [snap.yaml](.github/workflows/snap.yaml) - the main entry point to the overall workflow.
  It includes the other reusable workflows and integrate them into one single cohesive workflow. It is most likely the one you are looking for.
- [build.yaml](.github/workflows/build.yaml) - the workflow to build the snap.
- [test.yaml](.github/workflows/test.yaml) - the workflow to test the snap.
- [publish.yaml](.github/workflows/publish.yaml) - the workflow to publish the snap.
- [promote.yaml](.github/workflows/promote.yaml) - the workflow to promote the snap on the store.
- [generic-upstream-monitor.yaml](.github/workflows/generic-upstream-monitor.yaml) - the workflow to monitor new upstream versions.
- [upstream-gh-tag-monitor.yaml](.github/workflows/upstream-gh-tag-monitor.yaml) - the workflow to monitor new tag on an upstream repository.
- [bump-snap-version.yaml](.github/workflows/bump-snap-version.yaml) - the workflow to automate snap version bump PRs.
- [channel-risk-sync-monitor.yaml](.github/workflows/channel-risk-sync-monitor.yaml) - the workflow to monitor the promotion from a channel risk to another.

### General notes

The reusable workflows proposed here generally consider (but are not restricted to) the following 2 use cases:

- The `snapcraft.yaml` file lives alongside the source code.
  This is the main use case.
  On pull request, the snap is built and tested.
  It can be retrieved as a workflow artifact for further local testing and tinkering.
  On pushes & manual trigger (`workflow_call`),
  the snap is built, tested and also released on the Snap Store on the `edge` risk channel.
  Only on tags is the snap released on `candidate`.
  Promotion from `candidate` to `stable` is manual and expected to happen after thorough testing.
- The snapcraft file lives in its own repository.
  In this case the automated release schema is, in increasing precedence order:
  by default, the snap is published on `edge`.
  In case a tag triggered the workflow,
  the snap is released on `candidate`.
  At last, the user can explicitely set the risk.
  The snap version is expected to be updated appropriately with respect to the upstream code.
  Since keeping the snapcraft file, its git history and CI in sync with upstream can prove tedious,
  it is recommended to pin the source code version at a given tag (`parts.source-tag`),
  and solely update the snap on new upstream tag.

### The snap workflow

The [snap](.github/workflows/snap.yaml) workflow is the main reusable workflow.
It calls, in one go, the build,
test and release workflows as an integrated and coherent sequence.
As such, it exposes all configuration options of each sub-workflow as detailed in the next section.
By default it:

- builds the snap
- installs it and calls `snapcraft info` on it
- publishes it to the store,
  either to `latest/edge` on pushes to the branch or to `latest/candidate` on tags and releases.
  This workflow is only executed on `push` events.

For further configurations, see each sub-workflow details below.

#### Options

| Option | Default Value | Description | Required |
|---|---|---|---|
| `cleanup` | false | Whether to cleanup the artifacts. | false |
| `git-ref` | ${{ github.ref }} | The branch to checkout. | false |
| `lxd-image` | ' ' | The LXD image to run this action in. | false |
| `runs-on` | ubuntu-latest | The runner(s) to use. | false |
| `snap-install-args` | --dangerous | The argument to pass to snap install. | false |
| `snap-test-script` | ' ' | A test script to run against the snap. | false |
| `snap-risk` | edge | Snap Store channel risk use for publication. | false |
| `snap-track` | latest | Snap Store channel track use for publication. | false |
| `snapcraft-args` | ' ' | The arguments to pass to snapcraft (pack). | false |
| `snapcraft-channel` | latest/stable | The channel from which to install Snapcraft. | false |
| `snapcraft-enable-experimental-extensions` | false | Whether to enable Snapcraft experimental extensions or not. | false |
| `snapcraft-source-subdir` | ' . ' | The path where to execute snapcraft. | false |

#### Secrets

| Secret | Description | Required |
|---|---|---|
| `snapstore-login` | Store credential (see 'snapcraft export-login'). | false |

### The build workflow

The [build](.github/workflows/build.yaml) workflow,
as its name suggests,
builds the snap.
It does so using the [canonical/action-build](https://github.com/canonical/action-build) and the snap project it finds at the repository root.

Caller may specify one, or several,
sub-folders to build the snap(s) from using the `snapcraft-source-subdir` option (e.g. `snapcraft-source-subdir: 'my-path'` or `snapcraft-source-subdir: '["bar", "foo"]'`).

Caller may also use self-hosted runners using the `runs-on` option (e.g. `['ubuntu-latest', 'self-hosted']`)

The resulting snap(s) is then uploaded as an artifact prefixed with `workflow-build-snap-`.

#### Options

The `build` uses the following subset of options from the `snap` workflow:

- `git-ref`
- `runs-on`
- `snapcraft-args`
- `snapcraft-channel`
- `snapcraft-enable-experimental-extensions`
- `snapcraft-source-subdir`

### The test workflow

The [test](.github/workflows/test.yaml) workflow aims at testing the snap(s) built by the `build` workflow.
As such, its input is all the artefacts created during the run,
out of which it uses all the `*.snap` file it finds.
This allows for testing multiple snaps at once,
especially convenient for intricate multi-snaps deployments.

Similarly to the `build` workflow, callers can define the runner it is executed on.
Note that it will only install the snap(s) of matching architecture.

By default the workflow solely make sure the snap(s) is installable and calls `snapcraft info` on it.
However, the caller may provide an additional custom test as a bash script through the `snap-test-script` option.
For instance:

```yaml
snap-test-script: |
  #!/bin/sh
  set -euxo pipefail
  hello-snap | grep "Hello World"
```

Last but not least,
the entire workflow can be run in an [LXD container](https://canonical.com/lxd) allowing for testing on images that may not be available otherwise.
To do so, define a valid LXD image for the option `lxd-image` (e.g. `lxd-image: "ubuntu:20.04"`).

#### Options

The `test` uses the following subset of options from the `snap` workflow:

- `lxd-image`
- `runs-on`
- `git-ref`
- `snap-install-args`
- `snap-test-script`

### The publish workflow

The [publish](.github/workflows/publish.yaml) workflow publishes the snap(s) built during the run and after they've been tested.
It uses the [canonical/action-publish](https://github.com/canonical/action-publish) action to do so.

It publishes the snap to `edge` unless the GitHub reference is a tag,
in which case it publishes to `candidate`.

Note that all snaps from the `git-ref` branch are published to the same track defined by `snap-track` (e.g. `snap-track: 5.x`).

#### Options

The `publish` uses the following subset of options from the `snap` workflow:

- `git-ref`
- `snap-risk`
- `snap-track`


A complete working example can be found [here](https://github.com/canonical/turtlebot3c-snap/blob/main/.github/workflows/snap.yaml).

### The promote workflow

The [promote](.github/workflows/promote.yaml) workflow promotes a given snap from a channel to another.

#### Options

| Option | Default Value | Description | Required |
|---|---|---|---|
| `snap` |  | The snap to promote. | true |
| `from-channel` | latest/candidate | The channel from which to promote. | false |
| `to-channel` | latest/stable | The channel to which to promote. | false |

#### Secrets

| Secret | Description | Required |
|---|---|---|
| `snapstore-login` | Store credential (see 'snapcraft export-login'). | true |

### The generic-upstream-monitor workflow

The [generic-upstream-monitor](.github/workflows/generic-upstream-monitor.yaml) workflow aims at monitoring upstream for new version of the software.
This workflow is meant to be used when the `snapcraft.yaml` file lives outside the app source code and should be kept in sync with upstream releases.
In case a new version is found upstream,
the workflow opens a new issue suggesting updating the snap.

The workflow is said 'generic' in that it expects two user provided bash scripts:

- one script to retrieve the latest upstream version (see `script-get-upstream-version`).
  It must print the version, and solely the version, to stdout.
- one script to compare the version retrieved from the `snapcraft.yaml` to the version retrieved from the `script-get-upstream-version` script (see `script-compare-versions`).
  The script is called with both versions as arguments : `compare-versions <upstream-version> <snap-version>`.
  The script is expected to print on stdout the value `1` is case the upstream version is greater than the snap version. Any other value is ignored at the moment.

#### Options

| Option | Default Value | Description | Required |
|---|---|---|---|
| `git-ref` | ${{ github.ref }} | The branch to checkout. | false |
| `issue-assignee` | '' | Whom to assign the issue to. | false |
| `script-compare-versions` | '' | A bash script to compare versions. | false |
| `script-get-upstream-version` | '' | A bash script to retrieve the upstream version. | false |
| `snapcraft-source-subdir` | ' . ' | The directory of the snapcraft project. | false |

### The upstream-gh-tag-monitor workflow

The [upstream-gh-tag-monitor](.github/workflows/upstream-gh-tag-monitor.yaml) workflow is a specialization of the `generic-upstream-monitor` workflow.
It provides a `script-get-upstream-version` script that retrieve the latest tag of a given upstream GitHub repository as well as the `script-compare-versions` script that compares two semver versions.

#### Options

| Option | Default Value | Description | Required |
|---|---|---|---|
| `git-ref` | ${{ github.ref }} | The branch to checkout. | false |
| `issue-assignee` | '' | Whom to assign the issue to. | false |
| `snapcraft-source-subdir` | ' . ' | The directory of the snapcraft project. | false |
| `source-repo` | '' | The upstream repository to monitor in 'org/repo' form. | true |

### The bump-snap-version workflow

The [bump-snap-version](.github/workflows/bump-snap-version.yaml) workflow automates the creation of a version bump PR.
This workflow is designed to work in conjunction with the `upstream-gh-tag-monitor` workflow.
When a new version is detected upstream and an issue is opened,
this workflow can be triggered to automatically create a PR that updates the `snapcraft.yaml` file with the new version.

The workflow can operate in two modes:
- **Automatic mode** (recommended): When called without `new-version` and `issue-to-close` inputs, the workflow automatically finds the latest open monitoring issue (e.g., "[CI] Found version 'v0.27.0' upstream"), extracts the version from it, and proceeds with the bump.
- **Manual mode**: When `new-version` and `issue-to-close` are both provided, the workflow uses those values directly.

The workflow:
1. Finds the latest monitoring issue and extracts the version (if inputs not provided). If no monitoring issue is found, the workflow exits successfully without making changes.
2. Checks out the repository's default branch.
3. Creates a new branch based on the `new-version` (e.g., `feat/bump-v0.27.0`).
4. Finds the `snapcraft.yaml` file in the specified directory.
5. Updates the appropriate fields:
   - If `adopt-info` is used: only updates the `source-tag` field for the referenced part.
   - If `adopt-info` is not used: updates the top-level `version` field (removing the 'v' prefix) and the `source-tag` field for parts.
   - If multiple parts have `source-tag`, either updates the single part or requires the `source-tag-part` input to specify which part to update.
6. Commits the changes with a descriptive message.
7. Pushes the new branch to the repository.
8. Opens a new Pull Request that closes the specified issue.

#### Options

| Option | Default Value | Description | Required |
|---|---|---|---|
| `new-version` | '' | The new version tag (e.g., 'v0.27.0'). If not provided, will automatically find the latest monitoring issue. | false |
| `issue-to-close` | '' | The issue number that this PR will resolve (e.g., '108'). If not provided, will automatically find the latest monitoring issue. | false |
| `snapcraft-source-subdir` | ' . ' | The directory of the snapcraft project. | false |
| `pr-reviewer` | '' | The PR reviewer in the form '@name'. | false |
| `source-tag-part` | '' | The part name to update the source-tag for. Required when there are multiple parts with source-tag. | false |
| `git-ref` | ${{ github.ref }} | The branch to checkout. | false |

### The channel-risk-sync-monitor workflow

The [channel-risk-sync-monitor](.github/workflows/channel-risk-sync-monitor.yaml) workflow compares the publication date of a snap revision on a given risk level to that of 'today'.
If the difference is greater than or equal to a threshold,
it opens an issue.

#### Options

| Option | Default Value | Description | Required |
|---|---|---|---|
| `git-ref` | ${{ github.ref }} | The branch to checkout. | false |
| `issue-assignee` | '' | Whom to assign the issue to. | false |
| `snap-name` | '' | The snap name. | false |
| `snap-risk-aspirant` | 'candidate' | The risk level to compare. | false |
| `snap-risk-target` | 'stable' | The risk level target for the comparison. | false |
| `snap-track` | 'latest' | The track to use for the comparison. | false |
| `snapcraft-source-subdir` | ' . ' | The directory of the snapcraft project. | false |
| `threshold` | '10' | The threshold to trigger the issue (in days). | false |
