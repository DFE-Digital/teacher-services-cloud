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
