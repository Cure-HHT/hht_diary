#!/usr/bin/env node
/**
 * GraphQL Client for Linear API
 *
 * Provides consistent GraphQL communication with:
 * - Unified error handling
 * - Request/response logging (when debugging)
 * - Automatic retries for network issues
 * - Consistent authentication
 */

// Enable proxy support if HTTPS_PROXY is set
if (process.env.HTTPS_PROXY || process.env.GLOBAL_AGENT_HTTPS_PROXY) {
    try {
        require('global-agent/bootstrap');
    } catch (e) {
        // global-agent not available, continue without it
    }
}

const https = require('https');
const config = require('./config');

class GraphQLClient {
    constructor() {
        this.debug = process.env.DEBUG_GRAPHQL === 'true';
    }

    /**
     * Execute a GraphQL query or mutation
     * @param {string} query - The GraphQL query/mutation string
     * @param {Object} variables - Variables for the query
     * @param {Object} options - Additional options
     * @param {boolean} options.requireAuth - Whether authentication is required (default: true)
     * @param {number} options.maxRetries - Maximum retry attempts for network errors (default: 2)
     * @returns {Promise<Object>} The response data
     * @throws {Error} On GraphQL errors or network failures
     */
    async execute(query, variables = {}, options = {}) {
        const {
            requireAuth = true,
            maxRetries = 2
        } = options;

        // Get token if auth is required
        const token = requireAuth ? config.getToken(true) : null;

        // Parse API endpoint
        const endpoint = config.getApiEndpoint();
        const url = new URL(endpoint);

        // Prepare request data
        const requestData = JSON.stringify({ query, variables });

        if (this.debug) {
            console.log('🔍 GraphQL Request:');
            console.log('  Query:', query.substring(0, 100) + '...');
            console.log('  Variables:', JSON.stringify(variables, null, 2));
        }

        // Retry logic for network failures
        let lastError;
        for (let attempt = 0; attempt <= maxRetries; attempt++) {
            try {
                const response = await this._makeRequest(url, requestData, token);
                return this._handleResponse(response);
            } catch (error) {
                lastError = error;
                if (attempt < maxRetries && this._isRetryableError(error)) {
                    const delay = Math.min(1000 * Math.pow(2, attempt), 5000); // Exponential backoff
                    if (this.debug) {
                        console.log(`⚠️ Retrying after ${delay}ms (attempt ${attempt + 1}/${maxRetries})`);
                    }
                    await this._sleep(delay);
                } else {
                    break;
                }
            }
        }

        throw lastError;
    }

    /**
     * Make the actual HTTPS request
     * @private
     */
    _makeRequest(url, data, token) {
        return new Promise((resolve, reject) => {
            const options = {
                hostname: url.hostname,
                path: url.pathname,
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Content-Length': Buffer.byteLength(data)
                }
            };

            if (token) {
                options.headers['Authorization'] = token;
            }

            const req = https.request(options, (res) => {
                let body = '';
                res.on('data', chunk => body += chunk);
                res.on('end', () => {
                    resolve({
                        statusCode: res.statusCode,
                        statusMessage: res.statusMessage,
                        body
                    });
                });
            });

            req.on('error', (error) => {
                reject(new Error(`Network error: ${error.message}`));
            });

            req.on('timeout', () => {
                req.destroy();
                reject(new Error('Request timeout'));
            });

            req.setTimeout(30000); // 30 second timeout
            req.write(data);
            req.end();
        });
    }

    /**
     * Handle the HTTP response
     * @private
     */
    _handleResponse(response) {
        const { statusCode, statusMessage, body } = response;

        if (this.debug) {
            console.log(`📥 Response: ${statusCode} ${statusMessage}`);
        }

        // Check HTTP status
        if (statusCode >= 500) {
            throw new Error(`Linear API server error: ${statusCode} ${statusMessage}`);
        }

        if (statusCode === 401) {
            throw new Error('Authentication failed. Please check your LINEAR_API_TOKEN.');
        }

        if (statusCode === 403) {
            throw new Error('Permission denied. Your token may not have the required permissions.');
        }

        if (statusCode === 429) {
            throw new Error('Rate limit exceeded. Please wait a moment and try again.');
        }

        if (statusCode >= 400) {
            throw new Error(`Linear API error: ${statusCode} ${statusMessage}`);
        }

        // Parse JSON response
        let parsed;
        try {
            parsed = JSON.parse(body);
        } catch (error) {
            throw new Error(`Invalid JSON response from Linear API: ${error.message}`);
        }

        // Check for GraphQL errors
        if (parsed.errors && parsed.errors.length > 0) {
            const errorMessages = parsed.errors.map(e => {
                // Extract meaningful error message
                if (e.message) return e.message;
                if (e.extensions && e.extensions.userPresentableMessage) {
                    return e.extensions.userPresentableMessage;
                }
                return JSON.stringify(e);
            });

            const combinedMessage = errorMessages.join('; ');
            throw new Error(`GraphQL error: ${combinedMessage}`);
        }

        // Check for data
        if (!parsed.data) {
            throw new Error('No data in GraphQL response');
        }

        if (this.debug) {
            console.log('✅ GraphQL request successful');
        }

        return parsed.data;
    }

    /**
     * Check if an error is retryable
     * @private
     */
    _isRetryableError(error) {
        const message = error.message.toLowerCase();
        return (
            message.includes('network') ||
            message.includes('timeout') ||
            message.includes('econnreset') ||
            message.includes('enotfound') ||
            message.includes('rate limit') ||
            message.includes('server error')
        );
    }

    /**
     * Sleep for a given number of milliseconds
     * @private
     */
    _sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    /**
     * Execute a paginated query, fetching all pages
     * @param {string} query - GraphQL query with pagination support
     * @param {Object} variables - Query variables
     * @param {string} dataPath - Path to the paginated data (e.g., 'team.issues')
     * @returns {Promise<Array>} All items from all pages
     */
    async executePaginated(query, variables = {}, dataPath) {
        const items = [];
        let hasNextPage = true;
        let endCursor = null;

        while (hasNextPage) {
            const pageVariables = {
                ...variables,
                after: endCursor
            };

            const data = await this.execute(query, pageVariables);

            // Navigate to the paginated field
            let field = data;
            for (const key of dataPath.split('.')) {
                field = field[key];
                if (!field) break;
            }

            if (field && field.nodes) {
                items.push(...field.nodes);
            }

            hasNextPage = field?.pageInfo?.hasNextPage || false;
            endCursor = field?.pageInfo?.endCursor || null;
        }

        return items;
    }
}

// Export singleton instance
module.exports = new GraphQLClient();