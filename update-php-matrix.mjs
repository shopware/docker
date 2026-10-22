#!/usr/bin/env node

import fs from 'node:fs/promises';
import { bakeFilePath, readBakeFile, replaceVariable } from './scripts/bake-variables.mjs';

// Supported PHP major.minor versions
const supportedVersions = ['8.2', '8.3', '8.4', '8.5'];

const phpLibraryRepository = 'docker-library/php';
const phpVersionsPath = 'php-versions.json';

async function fetchJson(url) {
    const response = await fetch(url);
    if (!response.ok) {
        throw new Error(`Failed to fetch ${url}: ${response.status} ${response.statusText}`);
    }

    return response.json();
}

async function fetchLibraryVersions() {
    return fetchJson(`https://raw.githubusercontent.com/${phpLibraryRepository}/master/versions.json`);
}

// The official php:*-fpm-alpine images follow the newest Alpine release
function getLatestAlpineVersion(libraryVersions) {
    const alpineVersions = supportedVersions.flatMap(version => libraryVersions[version].variants ?? [])
        .map(variant => variant.match(/^alpine(\d+\.\d+)\/fpm$/)?.[1])
        .filter(Boolean)
        .sort((a, b) => a.localeCompare(b, undefined, { numeric: true }));

    if (alpineVersions.length === 0) {
        throw new Error('No Alpine variant found');
    }

    return alpineVersions.at(-1);
}

// php.net publishes releases before docker-library/php picks them up
async function fetchLatestRelease(version) {
    const release = await fetchJson(`https://www.php.net/releases/index.php?json&version=${version}`);
    const tarball = release.source?.find(source => source.filename === `php-${release.version}.tar.xz`);

    if (!/^\d+\.\d+\.\d+$/.test(release.version) || !tarball?.sha256) {
        throw new Error(`No valid release found for PHP ${version}`);
    }

    return { version: release.version, sha256: tarball.sha256 };
}

async function fetchReleases() {
    const entries = await Promise.all(supportedVersions.map(async version => [version, await fetchLatestRelease(version)]));
    return Object.fromEntries(entries);
}

async function updateBakeFile(releases, alpineVersion) {
    const phpVersions = supportedVersions.map(version => releases[version].version);
    const matrix = `[ ${phpVersions.map(v => `"${v}"`).join(', ')} ]`;

    let hclContent = await readBakeFile();
    hclContent = replaceVariable(hclContent, 'phpMatrix', matrix);
    hclContent = replaceVariable(hclContent, 'frankenphpMatrix', matrix);
    hclContent = replaceVariable(hclContent, 'alpineVersion', `"${alpineVersion}"`);

    await fs.writeFile(bakeFilePath, hclContent);
    await fs.writeFile(phpVersionsPath, `${JSON.stringify(releases, null, 4)}\n`);
    console.log(`Successfully updated ${bakeFilePath} and ${phpVersionsPath}`);
    console.log('PHP versions:', phpVersions);
    console.log('Alpine version:', alpineVersion);
}

const libraryVersions = await fetchLibraryVersions();

await updateBakeFile(await fetchReleases(), getLatestAlpineVersion(libraryVersions));
