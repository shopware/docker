#!/usr/bin/env node

import fs from 'node:fs/promises';

// Supported PHP major.minor versions
const supportedVersions = ['8.2', '8.3', '8.4', '8.5'];

const phpLibraryRepository = 'shopwareLabs/docker-php-library';
const frankenphpRepository = 'php/frankenphp';

async function request(url) {
    const headers = {};
    if (process.env.GITHUB_TOKEN && new URL(url).hostname === 'api.github.com') {
        headers.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`;
    }

    const response = await fetch(url, { headers });
    if (!response.ok) {
        throw new Error(`Failed to fetch ${url}: ${response.status} ${response.statusText}`);
    }

    return response;
}

async function readVariable(hclPath, name) {
    const hclContent = await fs.readFile(hclPath, 'utf8');
    return hclContent.match(new RegExp(`variable "${name}" \\{\\s*default = "([^"]*)"`))?.[1];
}

// Keep the pinned commit unless upstream changed a supported PHP version, so
// unrelated commits (e.g. release candidates of other versions) cause no rebuild
async function fetchPhpLibraryRef(currentRef) {
    if (currentRef) {
        const comparison = await (await request(`https://api.github.com/repos/${phpLibraryRepository}/compare/${currentRef}...master`)).json();
        const relevant = comparison.files?.some(file => supportedVersions.some(version => file.filename.startsWith(`${version}/`)));

        if (comparison.files && comparison.files.length < 300 && !relevant) {
            return currentRef;
        }
    }

    const commit = await (await request(`https://api.github.com/repos/${phpLibraryRepository}/commits/master`)).json();
    return commit.sha;
}

async function fetchVersions(ref) {
    return (await request(`https://raw.githubusercontent.com/${phpLibraryRepository}/${ref}/versions.json`)).json();
}

async function fetchFrankenphpVersion() {
    const release = await (await request(`https://api.github.com/repos/${frankenphpRepository}/releases/latest`)).json();
    return release.tag_name;
}

// Resolve the release tag to its commit, so a moved tag cannot change what is built
async function fetchFrankenphpRef(version) {
    const commit = await (await request(`https://api.github.com/repos/${frankenphpRepository}/commits/${version}`)).json();
    return commit.sha;
}

// FrankenPHP pins the Go version it is built with in its own Bake file
async function fetchGoVersion(ref) {
    const bakeFile = await (await request(`https://raw.githubusercontent.com/${frankenphpRepository}/${ref}/docker-bake.hcl`)).text();
    const goVersion = bakeFile.match(/variable "GO_VERSION" \{\s*default = "([^"]+)"/)?.[1];

    if (!goVersion) {
        throw new Error(`No Go version found in FrankenPHP ${ref}`);
    }

    return goVersion;
}

// The official php:*-fpm-alpine images follow the newest Alpine release
function getLatestAlpineVersion(versions) {
    const alpineVersions = supportedVersions
        .map(version => (versions[version].variants ?? [])
            .map(variant => variant.match(/^alpine(\d+\.\d+)\/fpm$/)?.[1])
            .filter(Boolean));

    // Only use an Alpine release every supported PHP version is available for
    const common = alpineVersions[0]
        .filter(alpine => alpineVersions.every(list => list.includes(alpine)))
        .sort((a, b) => a.localeCompare(b, undefined, { numeric: true }));

    if (common.length === 0) {
        throw new Error('No Alpine variant found');
    }

    return common.at(-1);
}

function getPhpVersions(versions) {
    return supportedVersions.map(version => {
        const entry = versions[version];
        if (!entry || !/^\d+\.\d+\.\d+$/.test(entry.version)) {
            throw new Error(`No valid version found for PHP ${version}`);
        }

        if (!entry.variants.includes('trixie/zts')) {
            throw new Error(`No trixie/zts variant found for PHP ${version}`);
        }

        return entry.version;
    });
}

async function updateVariables(hclPath, variables) {
    let hclContent = await fs.readFile(hclPath, 'utf8');

    for (const [name, value] of Object.entries(variables)) {
        const regex = new RegExp(`(variable "${name}" \\{\\s*default = )(\\[[^\\]]*\\]|"[^"]*")(\\s*\\})`, 's');

        if (!regex.test(hclContent)) {
            throw new Error(`${name} variable not found in ${hclPath}`);
        }

        const formatted = Array.isArray(value) ? `[ ${value.map(v => `"${v}"`).join(', ')} ]` : `"${value}"`;
        hclContent = hclContent.replace(regex, `$1${formatted}$3`);
        console.log(`${hclPath}: ${name} = ${formatted}`);
    }

    await fs.writeFile(hclPath, hclContent);
}

const phpLibraryRef = await fetchPhpLibraryRef(await readVariable('v1/docker-bake.hcl', 'phpLibraryRef'));
const versions = await fetchVersions(phpLibraryRef);
const phpVersions = getPhpVersions(versions);
const frankenphpVersion = await fetchFrankenphpVersion();
const frankenphpRef = await fetchFrankenphpRef(frankenphpVersion);

await updateVariables('v1/docker-bake.hcl', { phpLibraryRef });
await updateVariables('v1/fpm/docker-bake.hcl', {
    phpMatrix: phpVersions,
    alpineVersion: getLatestAlpineVersion(versions),
});
await updateVariables('v1/frankenphp/docker-bake.hcl', {
    frankenphpMatrix: phpVersions,
    frankenphpVersion,
    frankenphpRef,
    goVersion: await fetchGoVersion(frankenphpRef),
});
