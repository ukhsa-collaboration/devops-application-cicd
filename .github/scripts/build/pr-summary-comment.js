"use strict";

/**
 * Posts or updates the build summary as a pull-request comment.
 * Called from the actions/github-script step via:
 *   require('./.github/scripts/build/pr-summary-comment.js')({github, context, core})
 *
 * @param {object} params
 * @param {import("@octokit/rest").Octokit} params.github  – authenticated Octokit instance
 * @param {object} params.context – GitHub Actions context
 * @param {object} params.core    – @actions/core
 */
module.exports = async function postBuildSummary({ github, context, core }) {
  const fs = require("fs");
  const summaryPath = "ci-summary.md";

  if (!fs.existsSync(summaryPath)) {
    core.info("Summary file not found; skipping comment update.");
    return;
  }

  const issueNumber = context.payload?.pull_request?.number;
  if (!issueNumber) {
    core.info("No pull request number available; skipping comment update.");
    return;
  }

  const body = fs.readFileSync(summaryPath, "utf8");
  const marker = "<!-- container-image-build summary -->";
  const finalBody = `${marker}\n${body}`;

  const comments = await github.paginate(github.rest.issues.listComments, {
    issue_number: issueNumber,
    owner: context.repo.owner,
    repo: context.repo.repo,
  });

  const existing = comments.find(
    (comment) =>
      comment.user.type === "Bot" && comment.body.includes(marker)
  );

  if (existing) {
    await github.rest.issues.updateComment({
      owner: context.repo.owner,
      repo: context.repo.repo,
      comment_id: existing.id,
      body: finalBody,
    });
  } else {
    await github.rest.issues.createComment({
      owner: context.repo.owner,
      repo: context.repo.repo,
      issue_number: issueNumber,
      body: finalBody,
    });
  }
};
