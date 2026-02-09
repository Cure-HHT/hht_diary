import base64
import json
import os
import requests
from google.cloud import compute_v1 # Example for Compute Engine

THRESHOLD_EXHAUSTION_RATIO = 0.50 # 50% of budget
SLACK_WEBHOOK_URL = os.environ.get('SLACK_WEBHOOK_DEVOPS_URL', 'https://anspar.slack.com/archives/C0A494UM1C2')

def handle_budget_alert(event, context):
    """
    Cloud Run function triggered by a Pub/Sub message from a Google Cloud Budget alert.
    """
    if 'data' not in event:
        raise ValueError("No data in Pub/Sub event.")

    # Decode the Pub/Sub message data
    pubsub_message = base64.b64decode(event['data']).decode('utf-8')
    budget_alert = json.loads(pubsub_message)

    print(f"Received budget alert: {json.dumps(budget_alert, indent=2)}")

    # Extract relevant information from the budget alert
    # The structure of this payload can vary slightly, refer to Google Cloud's documentation
    # for the exact format of budget alert Pub/Sub messages.
    project_id = os.environ.get('GOOGLE_CLOUD_PROJECT', 'your-project-id') # Use env var or get from alert
    alert_threshold_exhaustion = budget_alert.get('alertThresholdExhaustionRatio')
    cost_amount = budget_alert.get('costAmount')
    budget_amount = budget_alert.get('budgetAmount')
    currency = budget_alert.get('currency')

    print(f"Project: {project_id}")
    print(f"Cost amount: {cost_amount} {currency}")
    print(f"Budget amount: {budget_amount} {currency}")
    print(f"Threshold exhausted: {alert_threshold_exhaustion * 100:.2f}%")

    # --- Implement your conditional actions here ---
    if alert_threshold_exhaustion >= THRESHOLD_EXHAUSTION_RATIO: # If costs exceed 50% of budget
        print("Warning: Budget threshold of 50% exceeded!")

        # --- Example: Hypothetical action for UAT environment ---
        # THIS IS HIGHLY SPECIFIC AND REQUIRES CAREFUL DESIGN!
        # You need to know exactly which resources to target.

        # Example: Stop a specific Compute Engine VM in UAT if it's safe to do so
        # THIS REQUIRES the Cloud Run service account to have 'compute.instances.stop' permission.
        # compute_client = compute_v1.InstancesClient()
        # instance_name = "my-uat-expensive-vm" # Replace with your VM name
        # zone = "us-central1-a" # Replace with your VM's zone
        #
        # try:
        #     print(f"Attempting to stop VM: {instance_name} in zone {zone}")
        #     operation = compute_client.stop(project=project_id, zone=zone, instance=instance_name)
        #     # You might need to wait for the operation to complete
        #     print(f"VM stop initiated: {operation.name}")
        # except Exception as e:
        #     print(f"Error stopping VM {instance_name}: {e}")

        # Example: Send a more urgent notification to a specific channel
        slack_webhook_url = os.environ.get(SLACK_WEBHOOK_URL)
        if slack_webhook_url:
            slack_message = {
                "text": f"🚨 URGENT: Budget for project '{project_id}' exceeded {int(THRESHOLD_EXHAUSTION_RATIO*100)}%! Current cost: {cost_amount} {currency}. Please investigate!"
            }
            requests.post(slack_webhook_url, json=slack_message)
            print("Sent urgent Slack notification.")
        else:
            print("Slack webhook URL not configured.")

    print("Budget alert processed successfully.")
