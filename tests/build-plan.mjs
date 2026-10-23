#!/usr/bin/env node
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';

function json(command, args, env = {}) {
    const result = spawnSync(command, args, { env: { ...process.env, ...env }, encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr);
    return JSON.parse(result.stdout);
}
const bake = env => json('docker', ['buildx', 'bake', '--print', 'daily'], env);
const local = bake({ phpMinor: '8.4', compiledSource: 'local' });
const published = bake({ phpMinor: '8.4', compiledSource: 'registry', compiledKey: 'test-inputs' });
assert.equal(Object.keys(local.target).filter(name => name.startsWith('artifacts-')).length, 2);
assert.equal(Object.keys(published.target).length, 12);
for (const runtime of ['fpm', 'frankenphp']) {
    const plain = published.target[`${runtime}-8-4`];
    const otel = published.target[`${runtime}-otel-8-4`];
    assert.equal(plain.contexts.artifacts, otel.contexts.artifacts, 'OTel must share the runtime artifact');
    assert.equal(otel.args.ENABLE_OTEL, '1');
    assert(!plain.args.ENABLE_OTEL);
}
for (const target of Object.values(published.target).filter(target => target.context === 'dev')) {
    assert(!target.contexts.artifacts, 'Dev must inherit extensions from FPM without another artifact');
}

assert(!Object.keys(published.target).some(name => /^(compiled-|artifacts-|php-|frankenphp-upstream)/.test(name)));
for (const [name, target] of Object.entries(published.target)) {
    assert.deepEqual(target.platforms, ['linux/amd64', 'linux/arm64']);
    assert(target.tags.length, name);
    if (target.contexts?.artifacts) assert.match(target.contexts.artifacts, /^docker-image:.*:test-inputs-/);
}
const pr = bake({ phpMinor: '8.4', compiledSource: 'registry', imageSuffix: '-ci-test', tagPrefix: '123-' });
for (const target of Object.values(pr.target)) {
    assert(target.tags.every(tag => tag.startsWith('ghcr.io/') && tag.includes('-ci-test:123-')));
}
const input = env => json('node', ['scripts/build-images.mjs', '--print', '--publish', 'daily'], env);
const first = input({ phpMinor: '8.4', osPackagesRefresh: 'day-1' });
const next = input({ phpMinor: '8.3', osPackagesRefresh: 'day-2', imageSuffix: '-ci-test', tagPrefix: '123-' });
assert.equal(first.key, next.key, 'Date, selected PHP minor and public tags must not change the compilation key');
const forced = input({ compiledRevision: 'test-forced-rebuild' });
assert.notEqual(first.key, forced.key, 'A manual compilation revision must change artifact tags');
const all = bake({ phpMinor: '', compiledSource: 'registry' });
assert.equal(Object.keys(all.target).length, 48);
console.log('PASS: 48 daily targets, both architectures, PR isolation, two artifact variants per PHP version, stable compilation keys, and no compilation in the published daily graph');
