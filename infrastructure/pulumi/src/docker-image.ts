/**
 * Docker Image Build and Push
 *
 * Handles:
 * 1. Creating Artifact Registry repository
 * 2. Building Flutter web app
 * 3. Building Docker image
 * 4. Pushing image to Artifact Registry
 */

import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";
import * as docker from "@pulumi/docker";
import { execSync } from "child_process";
import { StackConfig, resourceName, resourceLabels } from "./config";

/**
 * Create Artifact Registry repository for portal images
 */
export function createArtifactRegistry(config: StackConfig): gcp.artifactregistry.Repository {
    const repoName = resourceName(config, "portal");

    return new gcp.artifactregistry.Repository(repoName, {
        repositoryId: "clinical-diary",
        location: config.region,
        description: "Docker images for Clinical Trial Portal",
        format: "DOCKER",
        project: config.project,
        labels: resourceLabels(config),
    });
}

/**
 * Build Flutter web app
 */
function buildFlutterApp(config: StackConfig): void {
    pulumi.log.info("Building Flutter web app...");

    const buildCommand = `dart run tools/build_system/build_portal.dart \
        --sponsor-repo ${config.sponsorRepoPath} \
        --environment ${config.environment}`;

    try {
        execSync(buildCommand, {
            cwd: "../../", // Navigate to core repository root
            stdio: "inherit",
        });
        pulumi.log.info("Flutter build completed successfully");
    } catch (error) {
        throw new Error(`Flutter build failed: ${error}`);
    }
}

/**
 * Build and push Docker image to Artifact Registry
 */
export async function buildAndPushDockerImage(
    config: StackConfig,
    registry: gcp.artifactregistry.Repository
): Promise<docker.Image> {
    // Build Flutter web app first
    buildFlutterApp(config);

    // Generate image tag (use git commit hash if available)
    let imageTag: string;
    try {
        imageTag = execSync("git rev-parse --short HEAD").toString().trim();
    } catch {
        imageTag = `${Date.now()}`; // Fallback to timestamp
    }

    const imageName = pulumi.interpolate`${config.region}-docker.pkg.dev/${config.project}/clinical-diary/portal:${imageTag}`;

    // Build and push Docker image
    const image = new docker.Image("portal-image", {
        imageName: imageName,
        build: {
            context: "../..", // Build from core repository root
            dockerfile: "./apps/portal-cloud/Dockerfile",
            platform: "linux/amd64",
            args: {
                SPONSOR: config.sponsor,
                ENVIRONMENT: config.environment,
            },
        },
        registry: {
            server: pulumi.interpolate`${config.region}-docker.pkg.dev`,
        },
    }, { dependsOn: [registry] });

    return image;
}
