import assert from 'node:assert/strict';
import test from 'node:test';
import { getMetadata } from './bake-metadata.mjs';

test('resolves a single-target group without publishing its base target', () => {
    const definition = {
        group: { fpm: { targets: ['fpm-8-4'] } },
        target: {
            'php-fpm-alpine-8-4': { context: 'https://example.com/php.git' },
            'fpm-8-4': {
                contexts: { base: 'target:php-fpm-alpine-8-4' },
                tags: [
                    'shopware/docker-base:8.4-fpm',
                    'shopware/docker-base:8.4.27-fpm',
                    'ghcr.io/shopware/docker-base:8.4-fpm',
                    'ghcr.io/shopware/docker-base:8.4.27-fpm',
                ],
            },
        },
    };
    assert.deepEqual(getMetadata(definition, 'fpm'), {
        target: 'fpm-8-4',
        images: 'shopware/docker-base\nghcr.io/shopware/docker-base',
        tags: 'type=raw,value=8.4-fpm\ntype=raw,value=8.4.27-fpm',
    });
});

test('preserves PR dev tags without adding Docker Hub or latest', () => {
    const definition = {
        target: {
            'caddy-dev-8-4-24': {
                tags: [
                    'ghcr.io/shopware/docker-dev-ci-test:253-php8.4-node24-caddy',
                    'ghcr.io/shopware/docker-dev-ci-test:253-php8.4.27-node24-caddy',
                ],
            },
        },
    };
    assert.deepEqual(getMetadata(definition, 'caddy-dev-8-4-24'), {
        target: 'caddy-dev-8-4-24',
        images: 'ghcr.io/shopware/docker-dev-ci-test',
        tags: 'type=raw,value=253-php8.4-node24-caddy\ntype=raw,value=253-php8.4.27-node24-caddy',
    });
});

test('splits registry ports from image tags correctly', () => {
    assert.equal(getMetadata({ target: { image: { tags: ['localhost:5000/image:v1'] } } }, 'image').images, 'localhost:5000/image');
});

test('rejects a group containing multiple output images', () => {
    assert.throws(() => getMetadata({ group: { dev: { targets: ['node22', 'node24'] } } }, 'dev'), /Expected one output target/);
});

test('rejects missing or untagged targets', () => {
    assert.throws(() => getMetadata({}, 'missing'), /No image tags/);
    assert.throws(() => getMetadata({ target: { base: {} } }, 'base'), /No image tags/);
});

test('rejects differing registry tags instead of publishing additional tags', () => {
    const definition = { target: { image: { tags: ['shopware/image:v1', 'ghcr.io/shopware/image:v2'] } } };
    assert.throws(() => getMetadata(definition, 'image'), /Registries must have the same tags/);
});

test('rejects invalid tags that could be interpreted as metadata options', () => {
    const definition = { target: { image: { tags: ['shopware/image:v1,enable=false'] } } };
    assert.throws(() => getMetadata(definition, 'image'), /Invalid tagged image reference/);
});
