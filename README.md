# Robotics Actions Workflows

This repository hosts a collection of [reusable workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows) for building, testing & releasing robotics snaps.

Reusable workflows helps with the execution of scheduled workflows and reduces code duplication.
These workflows are intended to be re-used in github actions building snaps.
They implemented an opinionated workflow to build, test & release snaps.

## Description

The reusable workflows are:

- [snap.yaml](.github/workflows/snap.yaml) - the main entry point to the overall workflow.
  It includes the other reusable workflows and integrate them into on single cohesive workflow. It is most likely the one users should call.
- [snap-build.yaml](.github/workflows/snap-build.yaml) - the workflow to build the snap.
- [snap-test.yaml](.github/workflows/snap-test.yaml) - the workflow to test the snap.
- [snap-publish.yaml](.github/workflows/snap-publish.yaml) - the workflow to publish the snap.

## How to use

Below is shown an example on how to call these reusable workflows in a github repository to build and test a snap. The required input parameters must be defined for the workflow to run correctly.

```yaml
jobs:
  main-snap:
    uses: canonical/robotics-actions-workflows/.github/workflows/snap.yaml@main
    with:
      branch-name: main   ## this is the branch containing the snapcraft.yaml that we want to build
      snap-name: ros2-talker-listener
      snap-install-args: --devmode
      test-script: |
                    #!/bin/bash
                    echo "Testing custom bash script"
```

A complete working example can be found [here](https://github.com/canonical/turtlebot3c-snap/blob/main/.github/workflows/snap.yaml).
