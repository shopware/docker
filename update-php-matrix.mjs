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

// Function to fetch the manifest-list digest of a specific FrankenPHP tag (used for the v2 digest pins)
async function fetchFrankenPhpTagDigest(fullVersion) {
    const url = `https://hub.docker.com/v2/repositories/dunglas/frankenphp/tags/php${fullVersion}`;

    const response = await fetch(url);
    if (!response.ok) {
        throw new Error(`Failed to fetch FrankenPHP tag php${fullVersion}: ${response.status} ${response.statusText}`);
    }

    const jsonData = await response.json();
    if (!jsonData.digest) {
        throw new Error(`No digest found for FrankenPHP tag php${fullVersion}`);
    }

    return jsonData.digest;
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

// Function to fetch the manifest-list digest of the docker/dockerfile:1 frontend
async function fetchDockerfileFrontendDigest() {
    const url = 'https://hub.docker.com/v2/repositories/docker/dockerfile/tags/1';

    const response = await fetch(url);
    if (!response.ok) {
        throw new Error(`Failed to fetch docker/dockerfile:1 tag: ${response.status} ${response.statusText}`);
    }

    const jsonData = await response.json();
    if (!jsonData.digest) {
        throw new Error('No digest found for docker/dockerfile:1');
    }

    return jsonData.digest;
}

// Function to update the digest-pinned #syntax frontend line in the Dockerfiles of a versioned directory
async function updateDockerfileFrontendPin(versionDir, digest) {
    const dirents = await fs.readdir(versionDir, { withFileTypes: true });

    for (const dirent of dirents) {
        if (!dirent.isDirectory()) {
            continue;
        }

        const dockerfilePath = `${versionDir}/${dirent.name}/Dockerfile`;
        let content;
        try {
            content = await fs.readFile(dockerfilePath, 'utf8');
        } catch {
            continue;
        }

        const syntaxRegex = /^#syntax=docker\/dockerfile:1@sha256:[0-9a-f]{64}$/m;
        if (!syntaxRegex.test(content)) {
            continue;
        }

        content = content.replace(syntaxRegex, `#syntax=docker/dockerfile:1@${digest}`);
        await fs.writeFile(dockerfilePath, content);
        console.log(`Successfully updated dockerfile frontend pin in ${dockerfilePath}`);
    }
}

// Function to find the bake files of calendar-versioned images (v2026.1/docker-bake.hcl, ...)
async function findVersionedHclFiles() {
    const dirents = await fs.readdir('.', { withFileTypes: true });
    const files = [];

    for (const dirent of dirents) {
        if (!dirent.isDirectory() || !/^v\d{4}\.\d+$/.test(dirent.name)) {
            continue;
        }

        const hclPath = `${dirent.name}/docker-bake.hcl`;
        try {
            await fs.access(hclPath);
            files.push(hclPath);
        } catch {
            // version directory without a bake file — skip
        }
    }

    return files.sort();
}

// Function to update the digest-pinned frankenphpDigestMatrix in a versioned bake file
async function updateDigestMatrixInHcl(hclPath, entries) {
    let hclContent = await fs.readFile(hclPath, 'utf8');

    const digestMatrixRegex = /(variable "frankenphpDigestMatrix" \{[\s\S]*?default = )(\[[^\]]*\])(\s*\})/;

    if (!digestMatrixRegex.test(hclContent)) {
        throw new Error(`frankenphpDigestMatrix variable not found in ${hclPath}`);
    }

    const newMatrix = '[\n' + entries
        .map(e => `        { php = "${e.php}", digest = "${e.digest}" }`)
        .join(',\n') + '\n    ]';

    hclContent = hclContent.replace(digestMatrixRegex, `$1${newMatrix}$3`);

    await fs.writeFile(hclPath, hclContent);
    console.log(`Successfully updated frankenphpDigestMatrix in ${hclPath}`);
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

// Refresh the digest pins for the calendar-versioned images
const versionedHclFiles = await findVersionedHclFiles();

if (versionedHclFiles.length > 0) {
    const digestEntries = [];

    for (const version of frankenphpVersions) {
        console.log(`Fetching digest for FrankenPHP tag php${version}...`);
        const digest = await fetchFrankenPhpTagDigest(version);
        digestEntries.push({ php: version, digest });
        console.log(`Found digest for php${version}: ${digest}`);
    }

    for (const hclPath of versionedHclFiles) {
        await updateDigestMatrixInHcl(hclPath, digestEntries);
    }

    console.log('Fetching digest for docker/dockerfile:1 frontend...');
    const frontendDigest = await fetchDockerfileFrontendDigest();
    console.log(`Found digest for docker/dockerfile:1: ${frontendDigest}`);

    for (const hclPath of versionedHclFiles) {
        await updateDockerfileFrontendPin(hclPath.replace('/docker-bake.hcl', ''), frontendDigest);
    }
}
