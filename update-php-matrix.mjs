#!/usr/bin/env node

import fs from 'node:fs/promises';

// Supported PHP major.minor versions
const supportedVersions = ['8.2', '8.3', '8.4', '8.5'];

const phpLibraryRepository = 'docker-library/php';

async function fetchJson(url) {
    const response = await fetch(url);
    if (!response.ok) {
        throw new Error(`Failed to fetch ${url}: ${response.status} ${response.statusText}`);
    }

    return response.json();
}

async function fetchPhpLibraryRef() {
    const commit = await fetchJson(`https://api.github.com/repos/${phpLibraryRepository}/commits/master`);
    return commit.sha;
}

async function fetchVersions(ref) {
    return fetchJson(`https://raw.githubusercontent.com/${phpLibraryRepository}/${ref}/versions.json`);
}

// The official php:*-fpm-alpine images follow the newest Alpine release
function getLatestAlpineVersion(versions) {
    const alpineVersions = supportedVersions.flatMap(version => versions[version].variants ?? [])
        .map(variant => variant.match(/^alpine(\d+\.\d+)\/fpm$/)?.[1])
        .filter(Boolean)
        .sort((a, b) => a.localeCompare(b, undefined, { numeric: true }));

    if (alpineVersions.length === 0) {
        throw new Error('No Alpine variant found');
    }

    return alpineVersions.at(-1);
}

function getPhpVersions(versions) {
    return supportedVersions.map(version => {
        const entry = versions[version];
        if (!entry || !/^\d+\.\d+\.\d+$/.test(entry.version)) {
            throw new Error(`No valid version found for PHP ${version}`);
        }

        return entry.version;
    });
}

function replaceVariable(hclContent, name, value) {
    const regex = new RegExp(`(variable "${name}" \\{\\s*default = )(\\[[^\\]]*\\]|"[^"]*")(\\s*\\})`, 's');

    if (!regex.test(hclContent)) {
        throw new Error(`${name} variable not found in Bake configuration`);
    }

    return hclContent.replace(regex, `$1${value}$3`);
}

async function updateBakeFiles(phpVersions, phpLibraryRef, alpineVersion) {
    const matrix = `[ ${phpVersions.map(v => `"${v}"`).join(', ')} ]`;
    const updates = {
        'docker-bake.hcl': { phpLibraryRef: `"${phpLibraryRef}"` },
        'docker-bake.fpm.hcl': { phpMatrix: matrix, alpineVersion: `"${alpineVersion}"` },
        'docker-bake.frankenphp.hcl': { frankenphpMatrix: matrix },
    };

    for (const [hclPath, variables] of Object.entries(updates)) {
        let hclContent = await fs.readFile(hclPath, 'utf8');
        for (const [name, value] of Object.entries(variables)) {
            hclContent = replaceVariable(hclContent, name, value);
        }

        await fs.writeFile(hclPath, hclContent);
        console.log(`Successfully updated ${hclPath}`);
    }
    console.log('PHP versions:', phpVersions);
    console.log('docker-library/php ref:', phpLibraryRef);
    console.log('Alpine version:', alpineVersion);
}

const phpLibraryRef = await fetchPhpLibraryRef();
const versions = await fetchVersions(phpLibraryRef);

await updateBakeFiles(getPhpVersions(versions), phpLibraryRef, getLatestAlpineVersion(versions));
