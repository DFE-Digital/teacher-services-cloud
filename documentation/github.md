# GitHub Workflows and Security

## SHA Pinning Third Party Actions

### What is SHA Pinning?

SHA pinning is the practice of referencing GitHub Actions by their specific commit SHA instead of using version tags (like `v2.3.3`). This provides an immutable reference to the exact code that will run in your workflows.

### Why We SHA Pin External Actions

**Security Best Practice**: SHA pinning protects against tag manipulation attacks. Git tags are mutable - they can be moved to point to different commits, including malicious code. By pinning to a specific commit SHA, we ensure that the action code cannot be changed without our explicit approval.

**Trust Model**: We apply SHA pinning to less-trusted third-party actions (actions not from verified publishers or official GitHub actions). This creates a security boundary where we verify the exact code being executed.

### How We Implement SHA Pinning

In our GitHub Action workflows, we reference third-party actions using the full commit SHA with an inline comment documenting the version:

```yaml
- uses: rtCamp/action-slack-notify@e31e87e03dd19038e411e38ae27cbad084a90661 # Pinned at v2.3.3
```
This approach provides:
- **Immutability**: The SHA cannot be changed
- **Traceability**: The comment shows which version the SHA corresponds to
- **Auditability**: Clear documentation of what version is in use
### When to Apply SHA Pinning
Apply SHA pinning to:
- Third-party actions from community maintainers
- Actions from organizations without verified publisher status
- Any action where supply chain security is a concern
Do not apply SHA pinning to:
- Official GitHub actions (e.g., `actions/checkout`)
- Actions from verified trusted publishers
- First-party actions maintained by our team

## Dependabot Tracking for SHA-Pinned Actions

### Overview

This section explains how we track version updates for GitHub Actions that are pinned to commit SHAs for security purposes.

### The Problem

GitHub's Dependabot **does not track version updates or create security alerts** for actions pinned to commit SHAs. This creates a dilemma:

- **SHA pinning** is a security best practice (prevents tag manipulation attacks)
- **Dependabot tracking** requires semantic version tags
- We want **both** security and update notifications

### The Solution

We use a companion workflow file `.github/workflows/dependabot-tracking.yml` in the `github-actions` repository that:

1. References third-party actions using **semantic version tags**
2. Never actually runs (`if: false`)
3. Allows Dependabot to detect and alert on new versions
4. Documents the SHA-to-version mapping

#### Example Structure

```yaml
name: Dependabot Tracking (Never Runs)
on:
  workflow_dispatch:
jobs:
  tracking-only:
    if: false
    runs-on: ubuntu-latest
    steps:
      # rtCamp/action-slack-notify v2.3.3
      # SHA: e31e87e03dd19038e411e38ae27cbad084a90661
      - uses: rtCamp/action-slack-notify@v2.3.3
      # marocchino/sticky-pull-request-comment v2.9.4
      # SHA: 773744901bac0e8cbb5a0dc842800d45e9b2b405
      - uses: marocchino/sticky-pull-request-comment@v2.9.4
```

#### Actual Workflow Format

In the actual action files (e.g., `backup-postgres/action.yml`), we use SHA pinning with inline comments:

```yaml
- uses: rtCamp/action-slack-notify@e31e87e03dd19038e411e38ae27cbad084a90661 # Pinned at v2.3.3
```

### Manual Update Process

When Dependabot creates a PR to update `dependabot-tracking.yml`:

#### 1. Review Security

- Check release notes on GitHub: `https://github.com/OWNER/REPO/releases`
- Review changelog for breaking changes

#### 2. Find the Commit SHA

Get the SHA for the new version tag:

```bash
git ls-remote https://github.com/OWNER/REPO refs/tags/vX.Y.Z
```

Example output:
```
abc123def456...  refs/tags/v2.3.4
```

The first part (`abc123def456...`) is the full commit SHA you need.

### Currently Tracked Actions

#### rtCamp/action-slack-notify
- **Current Version**: v2.3.3
- **Current SHA**: `e31e87e03dd19038e411e38ae27cbad084a90661`

#### marocchino/sticky-pull-request-comment
- **Current Version**: v2.9.4
- **Current SHA**: `773744901bac0e8cbb5a0dc842800d45e9b2b405`


### Adding New Third-Party Actions

When adding a new third-party action to any workflow:

1. **Pin to SHA** in the actual workflow file:
   ```yaml
   - uses: owner/repo@COMMIT_SHA # Pinned at vX.Y.Z
   ```

2. **Add to tracking workflow** (`dependabot-tracking.yml`):
   ```yaml
   # owner/repo vX.Y.Z
   # SHA: COMMIT_SHA
   - uses: owner/repo@vX.Y.Z
   ```

3. **Document in this file** under "Currently Tracked Actions"
