#!/usr/bin/env node

import { execFile } from 'node:child_process';
import fs from 'node:fs/promises';
import { promisify } from 'node:util';
import { readBakeFile, readListVariable, readStringVariable } from './bake-variables.mjs';

const exec = promisify(execFile);

const libraryDirectory = '.php-library';
const overridePath = 'php-from-source.hcl';
const requiredPlatforms = ['linux/amd64', 'linux/arm64'];

const hcl = await readBakeFile();
const alpineVersion = readStringVariable(hcl, 'alpineVersion');
const debianVersion = readStringVariable(hcl, 'debianVersion');
const phpVersions = readListVariable(hcl, 'phpMatrix');
const releases = JSON.parse(await fs.readFile('php-versions.json', 'utf8'));

const variants = [
    {
        variable: 'phpFromSourceFpm',
        image: version => `docker.io/library/php:${version}-fpm-alpine${alpineVersion}`,
        directory: minor => `${minor}/alpine${alpineVersion}/fpm`,
    },
    {
        variable: 'phpFromSourceZts',
        image: version => `docker.io/library/php:${version}-zts-${debianVersion}`,
        directory: minor => `${minor}/${debianVersion}/zts`,
    },
];

async function isPublishedForAllPlatforms(image) {
    try {
        const { stdout } = await exec('docker', ['buildx', 'imagetools', 'inspect', image, '--raw']);
        const platforms = (JSON.parse(stdout).manifests ?? [])
            .map(({ platform }) => platform && `${platform.os}/${platform.architecture}`);

        return requiredPlatforms.every(platform => platforms.includes(platform));
    } catch {
        return false;
    }
}

function patchDockerfile(content, release) {
    const patches = [
        [/^ENV PHP_VERSION .*$/m, `ENV PHP_VERSION ${release.version}`],
        [/^(ENV PHP_URL=")[^"]*(" PHP_ASC_URL=")[^"]*(")$/m, `$1https://www.php.net/distributions/php-${release.version}.tar.xz$2https://www.php.net/distributions/php-${release.version}.tar.xz.asc$3`],
        [/^ENV PHP_SHA256=".*"$/m, `ENV PHP_SHA256="${release.sha256}"`],
    ];

    return patches.reduce((patched, [pattern, replacement]) => {
        if (!pattern.test(patched)) {
            throw new Error(`Dockerfile does not match ${pattern}`);
        }

        return patched.replace(pattern, replacement);
    }, content);
}

async function checkoutLibrary(directories) {
    await fs.rm(libraryDirectory, { recursive: true, force: true });
    await fs.mkdir(libraryDirectory);

    const git = (...args) => exec('git', args, { cwd: libraryDirectory });
    await git('init', '--quiet');
    await git('fetch', '--quiet', '--depth', '1', 'https://github.com/docker-library/php.git', 'master');
    await git('checkout', '--quiet', 'FETCH_HEAD', '--', ...directories);
}

const fromSource = Object.fromEntries(variants.map(({ variable }) => [variable, []]));

for (const version of phpVersions) {
    for (const variant of variants) {
        if (await isPublishedForAllPlatforms(variant.image(version))) {
            console.log(`Using published image ${variant.image(version)}`);
        } else {
            console.log(`Building ${variant.variable} ${version} from source`);
            fromSource[variant.variable].push(version);
        }
    }
}

const sourceDirectories = variants.flatMap(({ variable, directory }) =>
    fromSource[variable].map(version => directory(version.split('.').slice(0, 2).join('.'))));

if (sourceDirectories.length > 0) {
    await checkoutLibrary(sourceDirectories);

    for (const { variable, directory } of variants) {
        for (const version of fromSource[variable]) {
            const minor = version.split('.').slice(0, 2).join('.');
            const release = releases[minor];
            if (release?.version !== version) {
                throw new Error(`php-versions.json does not contain PHP ${version}`);
            }

            const dockerfilePath = `${libraryDirectory}/${directory(minor)}/Dockerfile`;
            await fs.writeFile(dockerfilePath, patchDockerfile(await fs.readFile(dockerfilePath, 'utf8'), release));
        }
    }
}

const overrides = variants.map(({ variable }) =>
    `variable "${variable}" {\n    default = [ ${fromSource[variable].map(version => `"${version}"`).join(', ')} ]\n}\n`);
await fs.writeFile(overridePath, overrides.join('\n'));
console.log(`Wrote ${overridePath}`);
