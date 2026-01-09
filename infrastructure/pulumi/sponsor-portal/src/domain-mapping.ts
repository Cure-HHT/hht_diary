/**
 * Custom Domain Mapping
 *
 * Maps custom domain to Cloud Run service with automatic SSL certificate provisioning.
 */

import * as gcp from "@pulumi/gcp";
import { StackConfig } from "./config";

/**
 * Create custom domain mapping for portal
 */
export function createDomainMapping(
    config: StackConfig,
    service: gcp.cloudrun.Service
): gcp.cloudrun.DomainMapping {
    const domainMapping = new gcp.cloudrun.DomainMapping(`${config.sponsor}-${config.environment}-domain`, {
        name: config.domainName,
        location: config.region,
        project: config.project,
        spec: {
            routeName: service.name,
        },
        metadata: {
            namespace: config.project,
        },
    });

    return domainMapping;
}
