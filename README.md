# Robotics Actions Workflows

This repository hosts a collection of [reusable workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows) for building, testing & releasing robotics snaps.

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
| `snap-track` | latest | Snap Store channel track use for publication. | false |
| `snapcraft-args` | ' ' | The arguments to pass to snapcraft (pack). | false |
| `snapcraft-channel` | latest/stable | The channel from which to install Snapcraft. | false |
| `snapcraft-enable-experimental-extensions` | false | Whether to enable Snapcraft experimental extensions or not. | false |
| `snapcraft-source-subdir` | ' . ' | The path where to execute snapcraft. | false |

#### Secrets

| Secret | Description | Required |
|---|---|---|---|
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
- `snap-install-args`
- `snap-test-script`

### The publish workflow

The [publish](.github/workflows/publish.yaml) workflow publishes the snap(s) built during the run and after they've been tested.
It uses the [canonical/action-publish](https://github.com/canonical/action-publish) action to do so.

It publishes the snap to `edge` unless the GitHub reference is a tag,
in which case it publishes to `candidate`.

Note that all snaps are published to the same track defined by `snap-track` (e.g. `snap-track: 5.x`).

#### Options

The `publish` uses the following subset of options from the `snap` workflow:

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
|---|---|---|---|
| `snapstore-login` | Store credential (see 'snapcraft export-login'). | true |
