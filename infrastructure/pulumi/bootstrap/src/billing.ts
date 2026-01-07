/**
 * Billing Configuration
 *
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-o00056: Pulumi IaC for portal deployment
 *
 * Note: Billing account linkage is handled during project creation
 * via the billingAccount property. This module provides utilities
 * for billing budgets and alerts.
 */

import * as gcp from "@pulumi/gcp";
import * as pulumi from "@pulumi/pulumi";
import { BootstrapConfig, Environment, getProjectId } from "./config";
import { ProjectResult } from "./projects";

/**
 * Budget configuration per environment
 * Production gets higher budget, dev/qa get lower
 */
const BUDGET_AMOUNTS: Record<Environment, number> = {
    dev: 500,    // $500/month
    qa: 500,     // $500/month
    uat: 1000,   // $1000/month
    prod: 5000,  // $5000/month
};

/**
 * Alert thresholds (percentage of budget)
 */
const ALERT_THRESHOLDS = [0.5, 0.75, 0.9, 1.0];

/**
 * Create billing budget for a project
 */
export function createBillingBudget(
    config: BootstrapConfig,
    env: Environment,
    projectResult: ProjectResult,
    notificationChannels?: string[]
): gcp.billing.Budget {
    const projectId = getProjectId(config, env);
    const budgetAmount = BUDGET_AMOUNTS[env];

    const budget = new gcp.billing.Budget(`${projectId}-budget`, {
        billingAccount: config.billingAccountId,
        displayName: `${projectId} Monthly Budget`,

        budgetFilter: {
            projects: [pulumi.interpolate`projects/${projectResult.project.number}`],
            creditTypesTreatment: "INCLUDE_ALL_CREDITS",
        },

        amount: {
            specifiedAmount: {
                currencyCode: "USD",
                units: budgetAmount.toString(),
            },
        },

        thresholdRules: ALERT_THRESHOLDS.map(threshold => ({
            thresholdPercent: threshold,
            spendBasis: "CURRENT_SPEND",
        })),

        // Optional: Add notification channels for alerts
        allUpdatesRule: notificationChannels ? {
            monitoringNotificationChannels: notificationChannels,
            disableDefaultIamRecipients: false,
        } : undefined,
    });

    return budget;
}

/**
 * Create billing budgets for all sponsor projects
 */
export function createSponsorBillingBudgets(
    config: BootstrapConfig,
    projects: Map<Environment, ProjectResult>,
    notificationChannels?: string[]
): Map<Environment, gcp.billing.Budget> {
    const budgets = new Map<Environment, gcp.billing.Budget>();

    for (const [env, projectResult] of projects) {
        pulumi.log.info(`Creating billing budget for ${config.sponsor}-${env}`);
        const budget = createBillingBudget(
            config,
            env,
            projectResult,
            notificationChannels
        );
        budgets.set(env, budget);
    }

    return budgets;
}
