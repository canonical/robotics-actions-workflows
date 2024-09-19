# Robotics Actions Workflows

Repository storing [reusable workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows) for robotics.

These workflows are intended to be re-used in github actions building snaps.

Having reusable workflows helps with the execution of scheduled workflows and reduces code duplication. Reusing workflows allows to create new workflows more quickly by avoiding to duplicate common steps.

In this repository there are two reusable workflows:

- [snap.yaml](https://github.com/canonical/robotics-actions-workflows/blob/main/.github/workflows/snap.yaml): this reusable workflow provides a template for building, installing and testing snaps. It provides various inputs to flexibly build snaps and it also allows the user to pass a custom bash script that can be used for testing.
- [snap-lxc.yaml](https://github.com/canonical/robotics-actions-workflows/blob/main/.github/workflows/snap-lxc.yaml): this reusable workflow uses the previous workflow to build snaps, but then it uses lxc containers to perform testing. This is useful in case we need to perform testing with the snap on deprecated images (e.g. ubuntu 18.04).


## How to use

Below is shown an example on how to call these reusable workflows in a github repository to build and test a snap. The required input parameters must be defined for the workflow to run correctly.


```
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
