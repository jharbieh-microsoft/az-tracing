// Azure Function Timer Trigger - Poll GitHub API and send metrics to Log Analytics
// Language: JavaScript (Node.js 18)
// Trigger: Timer trigger every 5 minutes

const https = require('https');
const crypto = require('crypto');
const axios = require('axios');

module.exports = async function(context, timer) {
    context.log('GitHub metrics collection function triggered at:', new Date().toISOString());

    try {
        // Step 1: Fetch GitHub user data and repositories
        const githubToken = process.env.GITHUB_TOKEN;
        const workspaceId = process.env.WORKSPACE_ID;
        const sharedKey = process.env.SHARED_KEY;

        if (!githubToken || !workspaceId || !sharedKey) {
            context.log.error('Missing required environment variables');
            throw new Error('Configuration missing: GITHUB_TOKEN, WORKSPACE_ID, or SHARED_KEY');
        }

        // Fetch GitHub repositories
        context.log('Fetching GitHub repositories...');
        const reposResponse = await axios.get('https://api.github.com/user/repos', {
            headers: {
                'Authorization': `Bearer ${githubToken}`,
                'Accept': 'application/vnd.github.v3+json',
                'User-Agent': 'Azure-Monitor-Demo'
            },
            params: {
                per_page: 100,
                type: 'owner',
                sort: 'updated'
            }
        });

        const repos = reposResponse.data;
        context.log(`Found ${repos.length} repositories`);

        // Step 2: Calculate metrics
        const metrics = {
            timestamp: new Date().toISOString(),
            repo_count: repos.length,
            active_repos: repos.filter(r => !r.archived).length,
            total_stars: repos.reduce((sum, r) => sum + r.stargazers_count, 0),
            total_watchers: repos.reduce((sum, r) => sum + r.watchers_count, 0),
            total_forks: repos.reduce((sum, r) => sum + r.forks_count, 0),
            avg_stars_per_repo: Math.round(repos.reduce((sum, r) => sum + r.stargazers_count, 0) / repos.length),
            languages_used: [...new Set(repos.map(r => r.language).filter(Boolean))].length,
            public_repos: repos.filter(r => !r.private).length,
            private_repos: repos.filter(r => r.private).length,
            updated_in_last_week: repos.filter(r => {
                const lastUpdate = new Date(r.pushed_at);
                const oneWeekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
                return lastUpdate > oneWeekAgo;
            }).length
        };

        context.log('Calculated metrics:', metrics);

        // Step 3: Send to Log Analytics via Data Collector API
        await sendToLogAnalytics(
            workspaceId,
            sharedKey,
            'GitHubMetrics_CL',
            [metrics],
            context
        );

        context.res = {
            status: 200,
            body: `Successfully sent GitHub metrics: ${metrics.repo_count} repos, ${metrics.total_stars} stars`
        };

    } catch (error) {
        context.log.error('Error in GitHub metrics function:', error.message);
        context.res = {
            status: 500,
            body: `Error: ${error.message}`
        };
    }
};

/**
 * Send data to Log Analytics via Data Collector API
 * @param {string} workspaceId - Log Analytics Workspace ID
 * @param {string} sharedKey - Workspace shared key (base64)
 * @param {string} tableName - Custom table name (with _CL suffix)
 * @param {Array} data - Array of JSON objects to send
 * @param {object} context - Azure Functions context for logging
 */
async function sendToLogAnalytics(workspaceId, sharedKey, tableName, data, context) {
    return new Promise((resolve, reject) => {
        const payload = JSON.stringify(data);
        const contentLength = Buffer.byteLength(payload);
        const timestamp = new Date().toUTCString();
        
        // Create authorization signature
        const sharedKeyBuffer = Buffer.from(sharedKey, 'base64');
        const stringToSign = `POST\n${contentLength}\napplication/json\nx-ms-date:${timestamp}\n/api/logs`;
        const signature = crypto.createHmac('sha256', sharedKeyBuffer)
            .update(stringToSign)
            .digest('base64');

        const options = {
            hostname: `${workspaceId}.ods.opinsights.azure.com`,
            port: 443,
            path: '/api/logs?api-version=2016-04-01',
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Content-Length': contentLength,
                'Log-Type': tableName,
                'Authorization': `SharedKey ${workspaceId}:${signature}`,
                'x-ms-date': timestamp,
                'x-ms-AzureCloud': 'AzurePublicCloud'
            }
        };

        context.log(`Sending ${data.length} records to ${tableName} table in Log Analytics`);

        const req = https.request(options, (res) => {
            let responseBody = '';

            res.on('data', (chunk) => {
                responseBody += chunk;
            });

            res.on('end', () => {
                if (res.statusCode === 200) {
                    context.log(`Successfully sent data to Log Analytics. Status: ${res.statusCode}`);
                    resolve(res.statusCode);
                } else {
                    context.log.error(`Log Analytics API returned status: ${res.statusCode}, Body: ${responseBody}`);
                    reject(new Error(`Log Analytics API returned ${res.statusCode}`));
                }
            });
        });

        req.on('error', (error) => {
            context.log.error('Error sending to Log Analytics:', error.message);
            reject(error);
        });

        req.write(payload);
        req.end();
    });
}
