#!/usr/bin/env node
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

const base = process.env.TEST_ALPINE_IMAGE ?? 'alpine:3.24';
const architecture = spawnSync('docker', ['run', '--rm', base, 'uname', '-m'], { encoding: 'utf8' });
assert.equal(architecture.status, 0, architecture.stderr);
const root = await mkdtemp(join(tmpdir(), 'shopware-artifact-compatibility-'));
async function check({ release = '3.24.999', arch = architecture.stdout.trim(), version = '8.4.27', valid }) {
    await writeFile(join(root, 'os-release'), `ID=alpine\nVERSION_ID=${release}\n`);
    await writeFile(join(root, 'architecture'), `${arch}\n`);
    await writeFile(join(root, 'php-version'), `${version}\n`);
    const result = spawnSync('docker', ['run', '--rm', '-e', 'PHP_VERSION=8.4.27',
        '--mount', `type=bind,source=${root},target=/compiled,readonly`,
        '--mount', `type=bind,source=${resolve('compiled/validate-runtime.sh')},target=/validate.sh,readonly`,
        base, 'sh', '/validate.sh'], { encoding: 'utf8' });
    assert.equal(result.status === 0, valid, `${JSON.stringify({ release, arch, version })}: ${result.stderr}`);
}
try {
    await check({ valid: true });
    await check({ release: '3.23.1', valid: false });
    await check({ arch: 'incompatible-architecture', valid: false });
    await check({ version: '8.3.1', valid: false });
    console.log('PASS: Alpine patch updates accepted; incompatible distro branches, architectures and PHP versions rejected');
} finally {
    await rm(root, { recursive: true, force: true });
}
