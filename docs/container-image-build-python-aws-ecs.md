# Container Image Build - Python/AWS ECS Workflow

This workflow is now an AWS ECS orchestrator built from two smaller reusable workflows:

- `build-test-container.yml` for linting, Python checks, image build, optional push, and optional signing.
- `deploy-aws-ecs.yml` for ECS task-definition updates, ECS service deployment, optional post-deploy tests, and smoke checks.

The public entrypoint is `.github/workflows/container-image-build-python-aws-ecs.yml`, but the implementation is split so build logic and deployment logic can evolve independently.

## Overview
- Prefers `pyproject.toml` (with pinned dependencies and optional extras) but falls back to requirements.txt and requirements-dev.txt files.
- Runs Hadolint and Ruff format/lint checks for Python projects.
- Supports arbitrary unit, integration, and post-build container smoke-test commands; results are summarised in the job summary and PR comments.
- Builds once and exposes an immutable image reference for downstream deployment.
- Deploys to Amazon ECS using the pushed image digest rather than a mutable tag.

## Prerequisites
- The calling repository must contain a Dockerfile and whatever Python/test assets your commands require.
- When pushing to ECR or signing images, provide either:
  - `registry_hostname`, or
  - `registry_account_id` so the workflow can derive the ECR hostname.
- When pushing or signing against the central ECR account, provide an IAM role ARN either via:
  - input `aws_registry_role_to_assume`, or
  - `registry_account_id` plus `aws_registry_role_name`, or
  - secret `AWS_REGISTRY_ROLE`.
- When deploying to workload accounts, provide either:
  - `aws_role_to_assume` per environment,
  - `aws_account_id` plus `aws_deploy_role_name` per environment,
  - `aws_account_id` per environment plus top-level `aws_deploy_role_name`, or
  - fall back to `AWS_DEPLOY_ROLE`.

## Required Inputs
| Input | Type | Description |
| --- | --- | --- |
| `app_name` | string | Application name used to name images and smoke-test messaging. |
| `service_identifier` | string | Identifier used for registry paths and ECS resource names. |

## Frequently Used Inputs
| Input | Type | Default | Purpose |
| --- | --- | --- | --- |
| `runner_labels` | string | `["ubuntu-latest"]` | JSON array of runner labels. |
| `run_unit_tests` | boolean | `true` | Enable/disable unit tests. |
| `unit_test_command` | string | `pytest -q` | Command executed for unit tests. |
| `run_integration_tests` | boolean | `false` | Toggle integration tests in the build job. |
| `integration_test_command` | string | `""` | Command executed when integration tests enabled. |
| `run_container_smoke_test` | boolean | `false` | Run a command against the built image after the Docker build completes. |
| `container_smoke_test_command` | string | `docker run --rm "$IMAGE_UNDER_TEST"` | Smoke-test command. The workflow exports `IMAGE_UNDER_TEST` for the command to use. |
| `registry_account_id` | string | `""` | AWS account id for ECR when `registry_hostname` is not supplied. |
| `aws_registry_role_name` | string | `""` | IAM role name in the central registry account; combined with `registry_account_id` to build the role ARN. |
| `aws_registry_role_to_assume` | string | `""` | IAM role ARN used only for central ECR image push and signing. |
| `push_image` | boolean | `false` | Push built image to the registry. Required for deployment. |
| `release_tag` | string | `""` | Optional release tag applied to the pushed image. |
| `deploy_environments` | string | `[]` | JSON array describing deployments. See below. |
| `aws_deploy_role_name` | string | `""` | Default workload-account deploy role name used with per-environment `aws_account_id`. |
| `registry_hostname` | string | `""` | Override registry host directly. |
| `lint_dockerfile` / `lint_python` | boolean | `true` | Toggle linting stages. |
| `sign_release` | boolean | `false` | Sign the pushed digest with Cosign during the release job. |
| `ecr_registry_namespace` | string | "" | The namespace of the ECR registry. Uses `service_identifier` if left empty. |

> Additional inputs are documented inline in `.github/workflows/container-image-build-python-aws-ecs.yml` but are not typically changed.

## Deployment Matrix Schema
Provide `deploy_environments` as a JSON array. Each object supports:

```json
[
  {
    "name": "dev",
    "aws_account_id": "210987654321",
    "aws_deploy_role_name": "github-deploy",
    "ssm_parameter_name": "/myapp/dev/image_tag",
    "task_definition": "my-ecs-task",
    "container_name": "app",
    "ecs_cluster": "my-ecs-cluster",
    "ecs_service": "my-ecs-service",
    "base_url": "https://dev.example.com",
    "integration_test_command": "pytest tests/integration --base-url=$BASE_URL",
    "deploy_script": "scripts/post_deploy.sh",
    "smoke_test_url": "https://dev.example.com/health"
  }
]
```

### Field Defaults
Fields are optional; the workflow supplies defaults for ECS resource naming:

| Field | Default | Notes |
| --- | --- | --- |
| `container_name` | `"app"` | ECS task container name; override for multi-container tasks. |
| `task_definition` | `aw-{service_identifier}-{region}-{environment}-ecssvc-{app}` | Derived from workflow inputs; override to use a different task definition. |
| `ecs_service` | `aw-{service_identifier}-{region}-{environment}-ecssvc-{app}` | Derived from workflow inputs; override to use a different service. |
| `ecs_cluster` | `aw-{service_identifier}-{region}-{environment}-ecscluster` | Derived from workflow inputs; override to use a different cluster. |

All other fields (`ssm_parameter_name`, `base_url`, `integration_test_command`, `deploy_script`, `smoke_test_url`) are optional and not provided by default.

The deploy job only runs when `deploy_environments` is non-empty and both `push_image` and `release_tag` are set.

Role resolution order is:
- `aws_role_to_assume`
- `aws_account_id` + `aws_deploy_role_name`
- `aws_account_id` + top-level `aws_deploy_role_name`
- `AWS_DEPLOY_ROLE`

## Quick Start

Choose the template that matches your needs. Adjust the version from `@main`.

### 1. Build and Test Only
```yaml
jobs:
  container:
    uses: ukhsa-collaboration/devops-application-cicd/.github/workflows/container-image-build-python-aws-ecs.yml@main
    with:
      app_name: my-app
      service_identifier: my-service
```
This runs linting, unit tests, builds the image locally, and reports results. Nothing is pushed.

### 2. Build, Test, and Push to ECR
```yaml
jobs:
  container:
    uses: ukhsa-collaboration/devops-application-cicd/.github/workflows/container-image-build-python-aws-ecs.yml@main
    with:
      app_name: my-app
      service_identifier: my-service
      registry_account_id: "123456789012"
      aws_registry_role_name: "github-ecr"
      push_image: ${{ github.ref == 'refs/heads/main' }}
      release_tag: ${{ github.ref_name }}
```
On main branch pushes, the image is tagged and pushed to ECR.

### 3. Full CI/CD: Build, Test, Push, and Deploy
```yaml
jobs:
  container:
    uses: ukhsa-collaboration/devops-application-cicd/.github/workflows/container-image-build-python-aws-ecs.yml@main
    with:
      app_name: my-app
      service_identifier: my-service
      registry_account_id: "123456789012"
      aws_registry_role_name: "github-ecr"
      aws_deploy_role_name: "github-deploy"
      push_image: ${{ github.ref == 'refs/heads/main' }}
      release_tag: ${{ github.ref_name }}
      deploy_environments: >-
        [
          {
            "name": "dev",
            "aws_account_id": "210987654321",
            "ecs_cluster": "my-cluster",
            "ecs_service": "my-service",
            "smoke_test_url": "https://dev.example.com/health"
          },
          {
            "name": "prd",
            "aws_account_id": "321098765432",
            "ecs_cluster": "my-cluster",
            "ecs_service": "my-service",
            "smoke_test_url": "https://prod.example.com/health"
          }
        ]
```
On main branch pushes, the image is pushed and automatically deployed to both dev and prod environments.

## Example Caller Workflow
```yaml
name: CI

on:
  push:
    branches: [ main ]
  pull_request:

jobs:
  container:
    uses: ukhsa-collaboration/devops-application-cicd/.github/workflows/container-image-build-python-aws-ecs.yml@v1
    with:
      app_name: frontend
      service_identifier: my-service
      registry_account_id: "123456789012"
      aws_registry_role_name: "github-ecr"
      run_container_smoke_test: true
      container_smoke_test_command: docker run --rm "$IMAGE_UNDER_TEST" | grep -F "service ready"
      push_image: ${{ github.ref == 'refs/heads/main' }}
      release_tag: ${{ github.ref_name }}
      aws_deploy_role_name: "github-deploy"
      deploy_environments: >-
        [
          {
            "name": "dev",
            "aws_account_id": "210987654321",
            "base_url": "https://dev.example.com",
            "smoke_test_url": "https://dev.example.com/health"
          }
        ]
```

## Regression Tests
`_test-container-image-build-python-aws-ecs.yml` reuses the orchestrator against a lightweight fixture in `fixtures/container_image_app`.

- The fixture ships with a pinned `pyproject.toml` (including `ruff` and `pytest`) and uses `tool.pytest.ini_options` so no `PYTHONPATH` overrides are required.
- The regression run now performs a post-build container smoke test and confirms that custom Docker build args are visible inside the running fixture image.
- Developers get the same Python version locally thanks to the `.python-version` file in the repo root.

When `run_container_smoke_test` is enabled, the workflow exports `IMAGE_UNDER_TEST` and executes `container_smoke_test_command` after the image build step. For build-only runs the image is tested from the local Docker daemon; for pushed images the workflow pulls the image reference before running the smoke command.

You can execute the regression workflow locally with [act](https://github.com/nektos/act):

```bash
act pull_request -W .github/workflows/_test-container-image-build-python-aws-ecs.yml --container-architecture linux/amd64
```

## Deployment Notes
- The deploy workflow consumes an immutable image reference (`image@sha256:...`) from the build workflow.
- The build workflow uses a registry-specific role for central ECR access; the deploy workflow uses workload-account roles for ECS updates.
- Per-environment deployment roles can be provided inline as a full ARN or derived from `aws_account_id` plus a role name.
- When `ssm_parameter_name` is provided, the workflow stores the immutable image reference rather than a mutable tag.
- This pattern assumes your Terraform pipeline reads that SSM parameter value during infra/apply runs and uses it as the image version source of truth.
- Reading the version from Parameter Store prevents config churn between application and infrastructure pipelines by decoupling image promotion from Terraform code changes.

## Notes
- Caching is intentionally minimal to ensure compatibility with self-hosted runners without GitHub cache services.

## Limitations

Current scope is intentionally minimal to ensure stability and clarity as the project matures:

- Single container per service: Only one application container per ECS task. Updating sidecars, logging agents, or other auxiliary containers is not currently supported.
- Rolling deployments only: ECS service deployments use basic rolling updates. Canary deployments, blue/green deployments, and traffic shifting patterns are not yet supported.
- Basic failure detection: The workflow waits for service stability but does not evaluate CloudWatch alarms or use ECS circuit breakers. Failed deployments are detected through ECS task health checks only.

These limitations will be addressed as the project matures. If your use case requires any of these features, please open an issue or consider managing those aspects separately in your post-deploy scripts.
