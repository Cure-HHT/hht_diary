/**
 * VPC Network Configuration
 *
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-o00056: Pulumi IaC for portal deployment
 *   REQ-p00005: Data security and isolation
 *
 * Creates VPC network infrastructure for secure Cloud SQL connectivity:
 * - Private VPC network (no auto-created subnets)
 * - Regional subnet with private Google access
 * - Private service connection for Cloud SQL
 * - VPC Access Connector for Cloud Run → Cloud SQL
 */

import * as gcp from "@pulumi/gcp";
import { StackConfig, resourceName } from "./config";

/**
 * VPC configuration options
 */
export interface VpcConfig {
    /** CIDR range for the main subnet */
    subnetCidr: string;
    /** CIDR range for VPC Access Connector (/28 required) */
    connectorCidr: string;
}

/**
 * Default VPC configuration
 */
export const defaultVpcConfig: VpcConfig = {
    subnetCidr: "10.0.0.0/20",
    connectorCidr: "10.8.0.0/28",
};

/**
 * Result of VPC creation
 */
export interface VpcResult {
    network: gcp.compute.Network;
    subnet: gcp.compute.Subnetwork;
    privateIpRange: gcp.compute.GlobalAddress;
    privateVpcConnection: gcp.servicenetworking.Connection;
    vpcConnector: gcp.vpcaccess.Connector;
}

/**
 * Create VPC network infrastructure
 *
 * This sets up a private network for Cloud SQL with:
 * - VPC network without auto-created subnets
 * - Regional subnet with private Google access enabled
 * - Private service connection for Cloud SQL private IP
 * - VPC Access Connector for serverless (Cloud Run) access
 */
export function createVpcNetwork(
    config: StackConfig,
    vpcConfig: VpcConfig = defaultVpcConfig,
    enabledApis: gcp.projects.Service[]
): VpcResult {
    // Create VPC network
    const network = new gcp.compute.Network(resourceName(config, "vpc"), {
        name: resourceName(config, "vpc"),
        project: config.project,
        autoCreateSubnetworks: false,
        description: `VPC network for ${config.sponsor} ${config.environment} portal`,
    }, { dependsOn: enabledApis });

    // Create subnet with private Google access
    const subnet = new gcp.compute.Subnetwork(resourceName(config, "subnet"), {
        name: resourceName(config, "subnet"),
        project: config.project,
        region: config.region,
        network: network.id,
        ipCidrRange: vpcConfig.subnetCidr,
        privateIpGoogleAccess: true,
        description: `Subnet for ${config.sponsor} ${config.environment} portal`,
    });

    // Reserve IP range for private service connection (Cloud SQL)
    const privateIpRange = new gcp.compute.GlobalAddress(
        resourceName(config, "private-ip-range"),
        {
            name: resourceName(config, "private-ip-range"),
            project: config.project,
            purpose: "VPC_PEERING",
            addressType: "INTERNAL",
            prefixLength: 16,
            network: network.id,
        }
    );

    // Create private VPC connection for Cloud SQL
    const privateVpcConnection = new gcp.servicenetworking.Connection(
        resourceName(config, "private-vpc-connection"),
        {
            network: network.id,
            service: "servicenetworking.googleapis.com",
            reservedPeeringRanges: [privateIpRange.name],
        },
        { dependsOn: enabledApis }
    );

    // Create VPC Access Connector for Cloud Run → Cloud SQL
    const connectorMinInstances = config.environment === "production" ? 2 : 2;
    const connectorMaxInstances = config.environment === "production" ? 10 : 3;

    const vpcConnector = new gcp.vpcaccess.Connector(
        resourceName(config, "vpc-connector"),
        {
            name: resourceName(config, "vpc-con"), // Max 25 chars
            project: config.project,
            region: config.region,
            network: network.name,
            ipCidrRange: vpcConfig.connectorCidr,
            minInstances: connectorMinInstances,
            maxInstances: connectorMaxInstances,
        },
        { dependsOn: enabledApis }
    );

    return {
        network,
        subnet,
        privateIpRange,
        privateVpcConnection,
        vpcConnector,
    };
}
