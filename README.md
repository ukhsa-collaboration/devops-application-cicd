 # Application Build CI/CD pipelines

This repository contains reusable application build and deployment workflows.

> :warning: To avoid unexpected breaking changes, it is recommended that you pin to a specific version of this repo using either a git tag or a commit hash and not to use `main`. This practice will help ensure the stability of your workflows.

## Getting Started

See the [Quick Start section](docs/container-image-build-python-aws-ecs.md#quick-start) in the Container Image Build workflow documentation for minimal copy-paste examples for common scenarios when deploying Python applications to AWS ECS.

## Workflows

1. [Container Image Build (Python/AWS ECS)](docs/container-image-build-python-aws-ecs.md)
2. [Container Image Build (JavaScript/AWS ECS)](docs/container-image-build-javascript-aws-ecs.md)

## Caution: aggressive cleanup

The reusable container build workflow supports an `aggressively_clean` input to remove common toolchains and caches before the image build runs. This can free space on the runner, but it is deliberately destructive and can remove components that later tests or downstream build steps still need.

Use it only on disposable or intentionally minimal runners, and avoid enabling it when the job depends on Java, .NET, Swift, Haskell, Android, browser tooling, Azure CLI, PowerShell, or existing Docker layers during the same workflow. In practice, this option is best reserved for very constrained runners where the build and test process does not rely on those toolchains after the cleanup step.
