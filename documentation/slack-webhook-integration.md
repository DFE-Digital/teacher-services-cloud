
### Step 1: Create a Webhook in Slack
- Documentation to create a webhook can be found in the technical guidance repo.
technical-guidance/source/infrastructure/monitoring/slack/index.html.md.erb

### Step 2: Create a Repository Secret in GitHub
- Navigate to your GitHub repository.
- Click on the Settings tab.
- On the left sidebar, click on Secrets.
- Click on New repository secret.
- For the Name, you might name it SLACK_WEBHOOK.
- For the Value, paste the Webhook URL from Slack.
- Click on Add secret.

### Step3: Secret Renewal
- Once the notification is received for an expiring secret
- Please refer to https://technical-guidance.education.gov.uk/infrastructure/hosting/azure-cip/#create-service-principal
- CIP team would need to refresh the secret
