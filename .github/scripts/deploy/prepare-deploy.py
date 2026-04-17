#!/usr/bin/env python3
"""Processes the deploy_environments input JSON array and emits a matrix JSON
to GITHUB_OUTPUT for the downstream deploy job strategy.

Inputs (env vars):
    RAW_ENVIRONMENTS      – raw JSON string from the deploy_environments workflow input
    SERVICE_IDENTIFIER    – identifier for naming default ECS resources
    APP_NAME              – application name for naming default ECS resources
    AWS_REGION            – AWS region for naming default ECS resources
    DEFAULT_DEPLOY_ROLE_NAME – fallback IAM role name when an environment only supplies
                               aws_account_id

Default ECS Resource Naming:
    container_name        – "app" (override in deploy_environments if needed)
    task_definition       – "aw-{service_identifier}-{region}-{environment}-ecssvc-{app_name}"
    ecs_service           – "aw-{service_identifier}-{region}-{environment}-ecssvc-{app_name}"
    ecs_cluster           – "aw-{service_identifier}-{region}-{environment}-ecscluster"

    All defaults can be overridden by providing the field explicitly in a deploy_environments entry.

Output (appended to GITHUB_OUTPUT):
    matrix – JSON array of fully-resolved environment descriptor objects
"""

import json
import os

raw = (os.getenv("RAW_ENVIRONMENTS") or "").strip()

if not raw:
    matrix = []
else:
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"deploy_environments must be valid JSON: {exc}")

    if not isinstance(data, list):
        raise SystemExit("deploy_environments must be a JSON array")

    service_identifier = os.getenv("SERVICE_IDENTIFIER") or ""
    app = os.getenv("APP_NAME") or ""
    region = os.getenv("AWS_REGION") or ""
    default_deploy_role_name = os.getenv("DEFAULT_DEPLOY_ROLE_NAME") or ""
    matrix = []

    for item in data:
        if isinstance(item, str):
            obj = {"name": item}
        elif isinstance(item, dict):
            obj = dict(item)
        else:
            continue

        name = obj.get("name")
        if not name:
            continue

        env_lower = str(name).lower()
        aws_account_id = obj.get("aws_account_id") or ""
        aws_deploy_role_name = (
            obj.get("aws_deploy_role_name") or default_deploy_role_name
        )

        # Apply naming conventions for ECS resources if not explicitly provided.
        # These defaults follow the pattern: aw-{service_identifier}-{region}-{environment}-{resource_type}.
        obj.setdefault("container_name", "app")
        obj.setdefault(
            "task_definition",
            f"aw-{service_identifier}-{region}-{env_lower}-ecssvc-{app}",
        )
        obj.setdefault(
            "ecs_service", f"aw-{service_identifier}-{region}-{env_lower}-ecssvc-{app}"
        )
        obj.setdefault(
            "ecs_cluster", f"aw-{service_identifier}-{region}-{env_lower}-ecscluster"
        )

        if (
            not obj.get("aws_role_to_assume")
            and aws_account_id
            and aws_deploy_role_name
        ):
            obj["aws_role_to_assume"] = (
                f"arn:aws:iam::{aws_account_id}:role/{aws_deploy_role_name}"
            )

        matrix.append(obj)

with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as fh:
    fh.write(f"matrix={json.dumps(matrix)}\n")
