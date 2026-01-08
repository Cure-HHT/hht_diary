# tools/cost-control/main.py
#
# Cloud Function to stop Cloud Run services when budget is exceeded
#
# Triggered by Pub/Sub messages from billing budget alerts.
# Only deployed to non-production environments.
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: IaC for portal deployment (cost protection)

import base64
import json
import logging
import os
from google.cloud import run_v2

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def stop_cloud_run_services(event, context):
    """
    Cloud Function triggered by Pub/Sub when budget threshold exceeded.

    Stops all Cloud Run services in the project to prevent further costs.

    Args:
        event: Pub/Sub event containing budget alert data
        context: Cloud Function context
    """
    # Parse the Pub/Sub message
    if 'data' in event:
        pubsub_data = base64.b64decode(event['data']).decode('utf-8')
        budget_notification = json.loads(pubsub_data)
    else:
        logger.error("No data in Pub/Sub message")
        return

    # Extract budget information
    cost_amount = budget_notification.get('costAmount', 0)
    budget_amount = budget_notification.get('budgetAmount', 0)
    alert_threshold = budget_notification.get('alertThresholdExceeded', 0)

    logger.info(f"Budget alert received: ${cost_amount} spent of ${budget_amount} budget")
    logger.info(f"Alert threshold exceeded: {alert_threshold * 100}%")

    # Only take action if we've exceeded 100% of budget
    if alert_threshold < 1.0:
        logger.info(f"Threshold {alert_threshold} < 1.0, no action needed")
        return

    # Get project ID from environment
    project_id = os.environ.get('GCP_PROJECT')
    if not project_id:
        # Try to get from budget notification
        budget_name = budget_notification.get('budgetDisplayName', '')
        # Budget name format: {sponsor}-{env}-budget
        logger.error(f"GCP_PROJECT not set, budget name: {budget_name}")
        return

    # Get region from environment (default to us-central1)
    region = os.environ.get('REGION', 'us-central1')

    logger.warning(f"BUDGET EXCEEDED! Stopping Cloud Run services in {project_id}")

    # Initialize Cloud Run client
    client = run_v2.ServicesClient()

    # List all services in the project/region
    parent = f"projects/{project_id}/locations/{region}"

    try:
        services = client.list_services(parent=parent)

        stopped_services = []
        for service in services:
            service_name = service.name
            logger.info(f"Scaling down service: {service_name}")

            # Update service to have 0 max instances (effectively stopping it)
            # Note: We can't delete the service (would lose config), but we can
            # scale it to 0 to stop billing

            # Get current service
            current_service = client.get_service(name=service_name)

            # Update scaling to 0
            current_service.template.scaling.max_instance_count = 0
            current_service.template.scaling.min_instance_count = 0

            # Apply update
            operation = client.update_service(service=current_service)
            operation.result()  # Wait for completion

            stopped_services.append(service_name.split('/')[-1])
            logger.info(f"Stopped service: {service_name}")

        if stopped_services:
            logger.warning(f"COST CONTROL: Stopped {len(stopped_services)} services: {stopped_services}")
            logger.warning("To restore services, manually update scaling in GCP Console or re-deploy")
        else:
            logger.info("No Cloud Run services found to stop")

    except Exception as e:
        logger.error(f"Error stopping services: {e}")
        raise


def health_check(request):
    """HTTP health check endpoint."""
    return "OK", 200
