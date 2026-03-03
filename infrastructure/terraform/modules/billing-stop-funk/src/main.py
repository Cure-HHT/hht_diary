"""Cloud Function to disable billing when budget threshold is exceeded.

Invoked by a Pub/Sub push subscription (HTTP POST with a Pub/Sub envelope).
When the alertThresholdExceeded reaches or exceeds the configured cutoff
(default 45%), the function unlinks the billing account from the project,
effectively halting all paid GCP services.

Returns 2xx on success so the subscription acknowledges the message, or 5xx
to trigger a retry / dead-letter delivery.

IMPLEMENTS REQUIREMENTS:
  REQ-o00001: Cost-control billing alerts
"""

import base64
import json
import os
import urllib.error
import urllib.request

import functions_framework
from google.cloud import billing_v1

PROJECT_ID = os.environ.get("GOOGLE_CLOUD_PROJECT", "")
THRESHOLD_CUTOFF = float(os.environ.get("THRESHOLD_CUTOFF", "0.50"))
SLACK_WEBHOOK_URL = os.environ.get("SLACK_WEBHOOK_URL", "")


def _post_to_slack(message):
    """Post a message to Slack via webhook. Logs and continues on failure."""
    if not SLACK_WEBHOOK_URL:
        # print(f"SLACK_WEBHOOK_URL not set – skipping notification: {message}")
        print(f"SLACK_WEBHOOK_URL not set – skipping notification.")
        return
    try:
        payload = json.dumps({"text": message}).encode("utf-8")
        req = urllib.request.Request(
            SLACK_WEBHOOK_URL,
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req):
            pass
        print("Slack notification sent")
    except urllib.error.URLError as e:
        print(f"WARNING: Slack notification failed: {e}")


@functions_framework.http
def handle_billing_stop(request):
    """Receive a budget alert via Pub/Sub push and disable billing if over threshold."""
    envelope = request.get_json(silent=True)

    if not envelope or "message" not in envelope:
        print("Bad request: missing Pub/Sub message envelope")
        return ("Bad Request: missing Pub/Sub message", 400)
    print(f"Received envelope: {json.dumps(envelope, indent=2, default=str)}")

    try:
        pubsub_data = base64.b64decode(
            envelope["message"]["data"]
        ).decode("utf-8")
        billing_alert = json.loads(pubsub_data)
        # print(f"Decoded billing alert: {json.dumps(billing_alert, indent=2, default=str)}")
        print("Decoded billing alert payload")
        if "alertThresholdExceeded" not in billing_alert:
            print("No alertThresholdExceeded – periodic cost update, skipping")
            return ("OK", 200)

        threshold_exceeded = float(billing_alert["alertThresholdExceeded"])
        budget_display_name = billing_alert.get("budgetDisplayName", "Unknown")
        cost_amount = float(billing_alert.get("costAmount", 0))
        budget_amount = float(billing_alert.get("budgetAmount", 0))

        # print(
        #     "Budget alert received: "
        #     f"cost={cost_amount:.2f}, budget={budget_amount:.2f}, "
        #     f"threshold_exceeded={threshold_exceeded:.2%}, "
        #     f"cutoff={THRESHOLD_CUTOFF:.2%}"
        # )

        if threshold_exceeded < THRESHOLD_CUTOFF:
            print(
                f"Threshold {threshold_exceeded:.2%} is below "
                f"cutoff {THRESHOLD_CUTOFF:.2%} – no action taken"
            )
            return ("OK", 200)

        if not PROJECT_ID:
            print("ERROR: GOOGLE_CLOUD_PROJECT not set, cannot disable billing")
            return ("Internal Server Error: project not configured", 500)

        print(
            f"DISABLING BILLING: threshold {threshold_exceeded:.2%} >= "
            f"cutoff {THRESHOLD_CUTOFF:.2%} for project {PROJECT_ID}"
        )

        client = billing_v1.CloudBillingClient()
        billing_info = client.get_project_billing_info(
            name=f"projects/{PROJECT_ID}"
        )
        billing_account = billing_info.billing_account_name or "(none)"
        print(
            f"Current billing account for project {PROJECT_ID}: "
            f"{billing_account} – unlinking now"
        )

        # Post Slack notification BEFORE unlinking so the message is
        # guaranteed to be sent regardless of billing-alert-funk timing.
        slack_message = (
            f":rotating_light: *Billing STOP for {budget_display_name}:* "
            f"Spend is *{cost_amount:.2f} USD* "
            f"(>{threshold_exceeded * 100:.0f}% of budget "
            f"*{budget_amount:.2f} USD*). "
            f"Unlinking billing account `{billing_account}` "
            f"from project `{PROJECT_ID}`."
        )
        _post_to_slack(slack_message)

        client.update_project_billing_info(
            name=f"projects/{PROJECT_ID}",
            project_billing_info=billing_v1.ProjectBillingInfo(
                billing_account_name=""  # Empty string = unlink billing account
            ),
        )

        print(
            f"Billing disabled for project {PROJECT_ID}: "
            f"unlinked {billing_account}"
        )
        return ("OK – billing disabled", 200)

    except (json.JSONDecodeError, KeyError, ValueError) as e:
        print(f"Error processing billing alert: {e}")
        return (f"Internal Server Error: {e}", 500)
    except Exception as e:
        print(f"Error disabling billing: {e}")
        return (f"Internal Server Error: {e}", 500)
