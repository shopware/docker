#!/usr/bin/env node

import fs from 'node:fs/promises';

// Supported PHP major.minor versions
const supportedVersions = ['8.1', '8.2', '8.3', '8.4'];

// Function to fetch PHP tags from Docker Hub API
async function fetchPhpTags(version) {
    const url = `https://hub.docker.com/v2/repositories/library/php/tags/?page_size=50&page=1&name=${version}.`;

    const response = await fetch(url);
    if (!response.ok) {
        throw new Error(`Failed to fetch PHP tags for version ${version}: ${response.status} ${response.statusText}`);
    }

    const jsonData = await response.json();
    return jsonData;
}

// Function to extract the latest patch version from the API response
function getLatestPatchVersion(apiResponse) {
    if (!apiResponse || !Array.isArray(apiResponse.results)) {
        throw new Error('Invalid API response');
    }

    for (const entry of apiResponse.results) {
        // Skip RC versions
        if (entry.name.includes('RC')) {
            continue;
        }

        // Extract version number (e.g., 8.1.33)
        const versionMatch = entry.name.match(/^(\d+\.\d+\.\d+)/);
        if (versionMatch) {
            return versionMatch[1];
        }
    }

    return null;
}

// Function to compare semantic versions
function compareVersions(v1, v2) {
    const parts1 = v1.split('.').map(Number);
    const parts2 = v2.split('.').map(Number);
    
    for (let i = 0; i < Math.max(parts1.length, parts2.length); i++) {
        const part1 = parts1[i] || 0;
        const part2 = parts2[i] || 0;
        
        if (part1 > part2) return 1;
        if (part1 < part2) return -1;
    }
    
    return 0;
}

// Function to fetch Shopware Core tags from GitHub
async function fetchShopwareTags() {
    const url = 'https://api.github.com/repos/shopware/core/tags?per_page=100';
    
    const response = await fetch(url);
    if (!response.ok) {
        throw new Error(`Failed to fetch Shopware tags: ${response.status} ${response.statusText}`);
    }
    
    const tags = await response.json();
    return tags;
}

// Function to get latest Shopware versions
function getLatestShopwareVersions(tags) {
    // Filter only stable versions (no RC)
    const stableVersions = tags
        .filter(tag => tag.name.match(/^v6\.\d+\.\d+\.\d+$/))
        .map(tag => ({
            version: tag.name.substring(1), // Remove 'v' prefix
            patch: tag.name.match(/v(6\.\d+\.\d+)/)[1] // Extract x.y.z (patch version)
        }));
    
    // Group by patch version (x.y.z) and get the latest bugfix for each
    const versionMap = new Map();
    for (const ver of stableVersions) {
        // Use proper version comparison
        if (!versionMap.has(ver.patch)) {
            versionMap.set(ver.patch, ver.version);
        } else {
            const current = versionMap.get(ver.patch);
            if (compareVersions(ver.version, current) > 0) {
                versionMap.set(ver.patch, ver.version);
            }
        }
    }
    
    // Get all unique versions, sorted in descending order
    const latestVersions = Array.from(versionMap.values())
        .sort((a, b) => compareVersions(b, a));
    
    // Return structured data with tags
    const result = [];
    
    // Add latest version with 'latest' tag and its version tag
    if (latestVersions.length > 0) {
        const latestVersion = latestVersions[0];
        // Add with 'latest' tag
        result.push({
            version: latestVersion,
            tag: 'latest'
        });
        // Also add with its version tag (e.g., "6.7.2")
        const versionTag = latestVersion.substring(0, latestVersion.lastIndexOf('.'));
        result.push({
            version: latestVersion,
            tag: versionTag
        });
    }
    
    // Add other recent patch versions with their patch version as tag
    // Skip the first one as we already added it
    for (let i = 1; i < latestVersions.length && i < 5; i++) {
        const version = latestVersions[i];
        // Use x.y.z format as tag (e.g., "6.7.1", "6.7.0", "6.6.10")
        const patchTag = version.substring(0, version.lastIndexOf('.'));
        result.push({
            version: version,
            tag: patchTag
        });
    }
    
    return result;
}

// Function to update the phpMatrix, frankenphpMatrix, and shopwareVersions in docker-bake.hcl
async function updateMatricesInHcl(phpVersions, shopwareVersions) {
    const hclPath = 'docker-bake.hcl';
    let hclContent = await fs.readFile(hclPath, 'utf8');

    // Find the phpMatrix variable and replace its value
    const phpMatrixRegex = /(variable "phpMatrix" \{\s*default = )(\[[^\]]*\])(\s*\})/s;
    const newPhpMatrix = `[ ${phpVersions.map(v => `"${v}"`).join(', ')} ]`;

    if (!phpMatrixRegex.test(hclContent)) {
        throw new Error('phpMatrix variable not found in docker-bake.hcl');
    }

    hclContent = hclContent.replace(phpMatrixRegex, `$1${newPhpMatrix}$3`);

    // Find the frankenphpMatrix variable and replace its value (excludes PHP 8.1)
    const frankenphpMatrixRegex = /(variable "frankenphpMatrix" \{\s*default = )(\[[^\]]*\])(\s*\})/s;
    const frankenphpVersions = phpVersions.filter(v => !v.startsWith('8.1'));
    const newFrankenphpMatrix = `[ ${frankenphpVersions.map(v => `"${v}"`).join(', ')} ]`;

    if (!frankenphpMatrixRegex.test(hclContent)) {
        throw new Error('frankenphpMatrix variable not found in docker-bake.hcl');
    }

    hclContent = hclContent.replace(frankenphpMatrixRegex, `$1${newFrankenphpMatrix}$3`);
    
    // Find the shopwareVersions variable and replace its value
    const shopwareVersionsRegex = /(variable "shopwareVersions" \{\s*default = )(\[[^\]]*\])(\s*\})/s;
    const newShopwareVersions = `[\n${shopwareVersions.map(v => `    {\n        version = "${v.version}"\n        tag = "${v.tag}"\n    }`).join(',\n')}\n  ]`;
    
    if (!shopwareVersionsRegex.test(hclContent)) {
        throw new Error('shopwareVersions variable not found in docker-bake.hcl');
    }
    
    hclContent = hclContent.replace(shopwareVersionsRegex, `$1${newShopwareVersions}$3`);

    await fs.writeFile(hclPath, hclContent);
    console.log('Successfully updated phpMatrix, frankenphpMatrix, and shopwareVersions in docker-bake.hcl');
    console.log('PHP versions:', phpVersions);
    console.log('FrankenPHP versions (excluding 8.1):', frankenphpVersions);
    console.log('Shopware versions:', shopwareVersions);
}

// Fetch PHP versions
const phpVersions = [];

for (const version of supportedVersions) {
    console.log(`Fetching latest patch version for PHP ${version}...`);
    const apiResponse = await fetchPhpTags(version);
    const latestVersion = getLatestPatchVersion(apiResponse);

    if (latestVersion) {
        phpVersions.push(latestVersion);
        console.log(`Found latest version for PHP ${version}: ${latestVersion}`);
    } else {
        throw new Error(`No valid version found for PHP ${version}`);
    }
}

// Fetch Shopware versions
console.log('\nFetching Shopware versions...');
const shopwareTags = await fetchShopwareTags();
const shopwareVersions = getLatestShopwareVersions(shopwareTags);
console.log('Found Shopware versions:', shopwareVersions);

// Update all matrices in HCL file
await updateMatricesInHcl(phpVersions, shopwareVersions);