import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import test from 'node:test';

const families = {
    fpm: ['fpm', 'fpm-otel', 'caddy', 'nginx', 'caddy-otel', 'nginx-otel', 'caddy-dev', 'nginx-dev'],
    frankenphp: ['frankenphp', 'frankenphp-otel'],
};

for (const pullRequest of [false, true]) {
    for (const [family, targets] of Object.entries(families)) {
        test(`${family}: preserve all ${pullRequest ? 'PR' : 'release'} tags and platforms`, () => {
            const options = {
                encoding: 'utf8',
                env: {
                    ...process.env,
                    imageSuffix: pullRequest ? '-ci-test' : '',
                    tagPrefix: pullRequest ? '123-' : '',
                },
                stdio: ['ignore', 'pipe', 'pipe'],
            };
            const definition = JSON.parse(execFileSync('docker', [
                'buildx', 'bake', '-f', 'v1/docker-bake.hcl',
                '-f', `v1/${family}/docker-bake.hcl`, '--print', ...targets,
            ], options));
            const matrix = JSON.parse(execFileSync(process.execPath, [
                'scripts/bake-matrix.mjs', family, ...targets,
            ], options));

            assert.deepEqual(matrix.include.map(entry => entry.target).sort(), Object.keys(definition.target).sort());
            for (const entry of matrix.include) {
                const target = definition.target[entry.target];
                const published = entry.images.split('\n').flatMap(image => entry.tags.split('\n').map(line => {
                    assert.match(line, /^type=raw,value=/);
                    return `${image}:${line.slice('type=raw,value='.length)}`;
                }));
                assert.deepEqual(published.sort(), [...target.tags].sort());
                assert.deepEqual(target.platforms, ['linux/amd64', 'linux/arm64']);
                assert.ok(target.secret.some(secret => secret.id === 'composer_auth'));
                if (pullRequest) {
                    assert.ok(published.every(tag => tag.startsWith('ghcr.io/shopware/') && tag.includes('-ci-test:123-')));
                    if (target.contexts?.base?.includes('ghcr.io/shopware/')) {
                        assert.ok(target.contexts.base.includes('-ci-test:123-'));
                    }
                } else {
                    assert.ok(published.every(tag => !tag.includes('-ci-test')));
                }
            }
        });
    }
}
