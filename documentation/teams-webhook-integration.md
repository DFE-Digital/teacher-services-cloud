# Teams webhook integration

Each webhook can send messages to a specific channel, and the infra team use these for github workflow, prometheus and statuscake alerts.

Each service should have at least one channel for these alerts to go to.

As our monitoring webhooks have a specific setup, the infra team can add webhooks by copying an existing webhook for any new services or teams channels.
