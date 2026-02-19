"""Cloud Function to forward GCP billing alerts to Slack.

Invoked by a Pub/Sub push subscription (HTTP POST with a Pub/Sub envelope).
Returns 2xx on success so the subscription acknowledges the message, or 5xx
to trigger a retry / dead-letter delivery.

IMPLEMENTS REQUIREMENTS:
  REQ-o00001: Cost-control billing alerts
"""

import base64
import json
import os
import urllib.request

import functions_framework

SLACK_WEBHOOK_URL = os.environ.get("SLACK_WEBHOOK_URL", "")


@functions_framework.http
def handle_budget_alert(request):
    """Receive a budget alert via Pub/Sub push and post a Slack notification."""
    envelope = request.get_json(silent=True)
    if not envelope or "message" not in envelope:
        print("Bad request: missing Pub/Sub message envelope")
        return ("Bad Request: missing Pub/Sub message", 400)

    try:
        pubsub_data = base64.b64decode(
            envelope["message"]["data"]
        ).decode("utf-8")
        billing_alert = json.loads(pubsub_data)

        budget_display_name = billing_alert.get("budgetDisplayName", "Unknown")
        cost_amount = float(billing_alert.get("costAmount", 0))
        forecast_amount = float(billing_alert.get("forecastAmount", 0))
        budget_amount = float(billing_alert.get("budgetAmount", 0))
        threshold_value = float(billing_alert.get("thresholdValue", 0)) * 100

        if cost_amount >= budget_amount * (threshold_value / 100):
            slack_message = (
                f"*Billing Alert for {budget_display_name}:* "
                f"Actual spend is *{cost_amount:.2f} USD* "
                f"(>{threshold_value:.0f}% of budget *{budget_amount:.2f} USD*). "
                f"Forecasted spend: *{forecast_amount:.2f} USD*."
            )
        else:
            slack_message = (
                f"*Billing Alert for {budget_display_name}:* "
                f"Current spend is *{cost_amount:.2f} USD*. "
                f"Forecasted spend: *{forecast_amount:.2f} USD*."
            )

        if SLACK_WEBHOOK_URL:
            payload = json.dumps({"text": slack_message}).encode("utf-8")
            req = urllib.request.Request(
                SLACK_WEBHOOK_URL,
                data=payload,
                headers={"Content-Type": "application/json"},
                method="POST",
            )
            urllib.request.urlopen(req)
            print(f"Slack notification sent: {budget_display_name}")
        else:
            message_id = envelope.get("message", {}).get("messageId", "unknown")
            publish_time = envelope.get("message", {}).get("publishTime", "unknown")
            print(f"SLACK_WEBHOOK_URL not set – skipping message_id={message_id}, publish_time={publish_time}")

        return ("OK", 200)

    except Exception as e:
        print(f"Error processing billing alert: {e}")
        return (f"Internal Server Error: {e}", 500)
