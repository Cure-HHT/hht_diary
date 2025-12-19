/**
 * Workforce Identity Federation Configuration
 *
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-o00056: Pulumi IaC for portal deployment
 *   REQ-p00042: Infrastructure audit trail for FDA compliance
 *
 * Configures Workforce Identity Federation to allow sponsor users
 * to authenticate using their organization's Identity Provider (IdP)
 * via SAML 2.0 or OIDC protocols.
 *
 * Supported IdPs:
 * - Microsoft Entra ID (Azure AD)
 * - Okta
 * - Google Workspace
 * - Any SAML 2.0 or OIDC compliant provider
 *
 * Benefits over Firebase Auth:
 * - GDPR compliant (no user data stored in Firebase)
 * - Enterprise SSO integration
 * - Users authenticate with existing corporate credentials
 * - Group-based access control from IdP
 *
 * @see https://cloud.google.com/iam/docs/workforce-identity-federation
 */

import * as gcp from "@pulumi/gcp";
import * as pulumi from "@pulumi/pulumi";
import { StackConfig, resourceName } from "./config";

/**
 * Workforce Identity Pool configuration for a sponsor
 */
export interface WorkforceIdentityConfig {
    /** Enable Workforce Identity Federation (false = skip creation) */
    enabled: boolean;

    /** Identity provider type */
    providerType: "oidc" | "saml";

    /** OIDC configuration (required if providerType is "oidc") */
    oidc?: {
        /** IdP issuer URI (e.g., https://login.microsoftonline.com/{tenant}/v2.0) */
        issuerUri: string;
        /** OAuth client ID from IdP */
        clientId: string;
        /** OAuth client secret from IdP (optional, for authorization code flow) */
        clientSecret?: pulumi.Output<string> | string;
        /** Web SSO response type */
        webSsoResponseType: "CODE" | "ID_TOKEN";
    };

    /** SAML configuration (required if providerType is "saml") */
    saml?: {
        /** IdP metadata XML (base64 encoded) or URL */
        idpMetadataXml: string;
    };

    /** Attribute mapping from IdP claims to Google attributes */
    attributeMapping: { [key: string]: string };

    /** Attribute condition (CEL expression to restrict access) */
    attributeCondition?: string;
}

/**
 * Result of Workforce Identity Federation setup
 */
export interface WorkforceIdentityResult {
    /** Workforce identity pool */
    pool: gcp.iam.WorkforcePool;
    /** Workforce identity pool provider */
    provider: gcp.iam.WorkforcePoolProvider;
    /** Pool resource name for IAM bindings */
    poolResourceName: pulumi.Output<string>;
}

/**
 * Create Workforce Identity Federation pool and provider for sponsor SSO
 *
 * This allows sponsor users to authenticate using their corporate IdP
 * (Microsoft Entra ID, Okta, etc.) without needing Google accounts.
 *
 * @param config Stack configuration
 * @param identityConfig Workforce Identity configuration
 * @returns Workforce Identity resources or undefined if disabled
 */
export function createWorkforceIdentityFederation(
    config: StackConfig,
    identityConfig: WorkforceIdentityConfig
): WorkforceIdentityResult | undefined {
    if (!identityConfig.enabled) {
        pulumi.log.info("Workforce Identity Federation disabled for this stack");
        return undefined;
    }

    const poolName = resourceName(config, "workforce-pool");
    const providerName = resourceName(config, "workforce-provider");

    // Create Workforce Identity Pool
    // One pool per sponsor to isolate identity namespaces
    const pool = new gcp.iam.WorkforcePool(poolName, {
        workforcePoolId: poolName,
        parent: `organizations/${config.gcpOrgId}`,
        location: "global",
        displayName: `${config.sponsor} Portal Users (${config.environment})`,
        description: `Workforce identity pool for ${config.sponsor} sponsor portal users`,
        disabled: false,
        // Session duration for federated tokens (1 hour default)
        sessionDuration: "3600s",
    });

    // Create Workforce Identity Pool Provider
    let provider: gcp.iam.WorkforcePoolProvider;

    if (identityConfig.providerType === "oidc" && identityConfig.oidc) {
        // OIDC Provider (Microsoft Entra ID, Okta, Google Workspace)
        provider = new gcp.iam.WorkforcePoolProvider(providerName, {
            workforcePoolId: pool.workforcePoolId,
            providerId: providerName,
            location: "global",
            displayName: `${config.sponsor} OIDC Provider`,
            description: `OIDC identity provider for ${config.sponsor}`,
            disabled: false,
            attributeMapping: identityConfig.attributeMapping,
            attributeCondition: identityConfig.attributeCondition,
            oidc: {
                issuerUri: identityConfig.oidc.issuerUri,
                clientId: identityConfig.oidc.clientId,
                clientSecret: identityConfig.oidc.clientSecret ? {
                    value: {
                        plainText: identityConfig.oidc.clientSecret,
                    },
                } : undefined,
                webSsoConfig: {
                    responseType: identityConfig.oidc.webSsoResponseType,
                    assertionClaimsBehavior: "MERGE_USER_INFO_OVER_ID_TOKEN_CLAIMS",
                },
            },
        }, { parent: pool });
    } else if (identityConfig.providerType === "saml" && identityConfig.saml) {
        // SAML Provider
        provider = new gcp.iam.WorkforcePoolProvider(providerName, {
            workforcePoolId: pool.workforcePoolId,
            providerId: providerName,
            location: "global",
            displayName: `${config.sponsor} SAML Provider`,
            description: `SAML identity provider for ${config.sponsor}`,
            disabled: false,
            attributeMapping: identityConfig.attributeMapping,
            attributeCondition: identityConfig.attributeCondition,
            saml: {
                idpMetadataXml: identityConfig.saml.idpMetadataXml,
            },
        }, { parent: pool });
    } else {
        throw new Error(
            `Invalid identity config: providerType=${identityConfig.providerType} ` +
            `requires matching oidc or saml configuration`
        );
    }

    // Generate pool resource name for IAM bindings
    const poolResourceName = pulumi.interpolate`locations/global/workforcePools/${pool.workforcePoolId}`;

    return {
        pool,
        provider,
        poolResourceName,
    };
}

/**
 * Grant IAM role to workforce identity pool members
 *
 * Use this to grant portal access to authenticated sponsor users.
 *
 * @param config Stack configuration
 * @param workforceIdentity Workforce identity result
 * @param role IAM role to grant (e.g., "roles/run.invoker")
 * @param resourceName Name for the IAM binding resource
 */
export function grantWorkforcePoolAccess(
    config: StackConfig,
    workforceIdentity: WorkforceIdentityResult,
    role: string,
    resourceNameSuffix: string
): gcp.projects.IAMMember {
    const bindingName = resourceName(config, `workforce-${resourceNameSuffix}`);

    return new gcp.projects.IAMMember(bindingName, {
        project: config.project,
        role: role,
        member: workforceIdentity.poolResourceName.apply(
            poolName => `principalSet://iam.googleapis.com/${poolName}/*`
        ),
    });
}

/**
 * Example configurations for common IdPs
 */
export const IdPExamples = {
    /**
     * Microsoft Entra ID (Azure AD) OIDC configuration
     * Replace {tenant-id} and {client-id} with actual values
     */
    microsoftEntraId: {
        enabled: true,
        providerType: "oidc" as const,
        oidc: {
            issuerUri: "https://login.microsoftonline.com/{tenant-id}/v2.0",
            clientId: "{client-id}",
            webSsoResponseType: "CODE" as const,
        },
        attributeMapping: {
            "google.subject": "assertion.sub",
            "google.groups": "assertion.groups",
            "attribute.email": "assertion.email",
            "attribute.name": "assertion.name",
        },
        attributeCondition: undefined,
    },

    /**
     * Okta OIDC configuration
     * Replace {okta-domain} and {client-id} with actual values
     */
    okta: {
        enabled: true,
        providerType: "oidc" as const,
        oidc: {
            issuerUri: "https://{okta-domain}.okta.com",
            clientId: "{client-id}",
            webSsoResponseType: "CODE" as const,
        },
        attributeMapping: {
            "google.subject": "assertion.sub",
            "google.groups": "assertion.groups",
            "attribute.email": "assertion.email",
            "attribute.name": "assertion.name",
        },
        attributeCondition: undefined,
    },

    /**
     * Google Workspace OIDC configuration
     * Replace {client-id} with actual value
     */
    googleWorkspace: {
        enabled: true,
        providerType: "oidc" as const,
        oidc: {
            issuerUri: "https://accounts.google.com",
            clientId: "{client-id}",
            webSsoResponseType: "CODE" as const,
        },
        attributeMapping: {
            "google.subject": "assertion.sub",
            "attribute.email": "assertion.email",
            "attribute.name": "assertion.name",
        },
        attributeCondition: undefined,
    },
};
