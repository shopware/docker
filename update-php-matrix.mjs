#!/usr/bin/env node

import fs from 'node:fs/promises';

// Supported PHP major.minor versions
const supportedVersions = ['8.2', '8.3', '8.4', '8.5'];

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

// Function to fetch FrankenPHP tags from Docker Hub API
async function fetchFrankenPhpTags(version) {
    const url = `https://hub.docker.com/v2/repositories/dunglas/frankenphp/tags/?page_size=50&page=1&name=php${version}.`;

    const response = await fetch(url);
    if (!response.ok) {
        throw new Error(`Failed to fetch FrankenPHP tags for version ${version}: ${response.status} ${response.statusText}`);
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

// Function to extract the latest PHP patch version from FrankenPHP API response
function getLatestFrankenphpPatchVersion(apiResponse) {
    if (!apiResponse || !Array.isArray(apiResponse.results)) {
        throw new Error('Invalid API response');
    }

    for (const entry of apiResponse.results) {
        // Skip RC versions
        if (entry.name.includes('RC')) {
            continue;
        }

        // Extract PHP version number from FrankenPHP tag (e.g., 1.9.1-php8.2.29 -> 8.2.29)
        const versionMatch = entry.name.match(/-php(\d+\.\d+\.\d+)$/);
        if (versionMatch) {
            return versionMatch[1];
        }
    }

    return null;
}

// Function to update the phpMatrix and frankenphpMatrix in docker-bake.hcl
async function updatePhpMatrixInHcl(phpVersions, frankenphpVersions) {
    const hclPath = 'docker-bake.hcl';
    let hclContent = await fs.readFile(hclPath, 'utf8');

    // Find the phpMatrix variable and replace its value
    const phpMatrixRegex = /(variable "phpMatrix" \{\s*default = )(\[[^\]]*\])(\s*\})/s;
    const newPhpMatrix = `[ ${phpVersions.map(v => `"${v}"`).join(', ')} ]`;

    if (!phpMatrixRegex.test(hclContent)) {
        throw new Error('phpMatrix variable not found in docker-bake.hcl');
    }

    hclContent = hclContent.replace(phpMatrixRegex, `$1${newPhpMatrix}$3`);

    // Find the frankenphpMatrix variable and replace its value
    const frankenphpMatrixRegex = /(variable "frankenphpMatrix" \{\s*default = )(\[[^\]]*\])(\s*\})/s;
    const newFrankenphpMatrix = `[ ${frankenphpVersions.map(v => `"${v}"`).join(', ')} ]`;

    if (!frankenphpMatrixRegex.test(hclContent)) {
        throw new Error('frankenphpMatrix variable not found in docker-bake.hcl');
    }

    hclContent = hclContent.replace(frankenphpMatrixRegex, `$1${newFrankenphpMatrix}$3`);

    await fs.writeFile(hclPath, hclContent);
    console.log('Successfully updated phpMatrix and frankenphpMatrix in docker-bake.hcl');
    console.log('PHP versions:', phpVersions);
    console.log('FrankenPHP versions:', frankenphpVersions);
}

const phpVersions = [];
const frankenphpVersions = [];

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

    console.log(`Fetching FrankenPHP version for PHP ${version}...`);
    const frankenphpApiResponse = await fetchFrankenPhpTags(version);
    const frankenphpLatestVersion = getLatestFrankenphpPatchVersion(frankenphpApiResponse);
    
    if (frankenphpLatestVersion) {
        frankenphpVersions.push(frankenphpLatestVersion);
        console.log(`Found FrankenPHP version for PHP ${version}: ${frankenphpLatestVersion}`);
    } else {
        console.log(`No FrankenPHP version found for PHP ${version}, skipping...`);
    }
}

await updatePhpMatrixInHcl(phpVersions, frankenphpVersions);
