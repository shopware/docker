#!/usr/bin/env node

import { execFileSync } from 'node:child_process';

const [family, ...targets] = process.argv.slice(2);
if (!['fpm', 'frankenphp'].includes(family) || targets.length === 0) {
    throw new Error('Usage: node scripts/bake-matrix.mjs <fpm|frankenphp> <target> [...]');
}

const definition = JSON.parse(execFileSync('docker', [
    'buildx', 'bake', '-f', 'v1/docker-bake.hcl',
    '-f', `v1/${family}/docker-bake.hcl`, '--print', ...targets,
], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'inherit'] }));

// github-builder publishes one concrete target per call and replaces Bake's tags
// with metadata-action output. Derive both inputs from Bake to keep one source.
const include = Object.entries(definition.target).map(([target, config]) => {
    if (!config.tags?.length) {
        throw new Error(`Bake target ${target} has no publication tags`);
    }
    const images = new Map();
    for (const ref of config.tags) {
        const separator = ref.lastIndexOf(':');
        if (separator <= ref.lastIndexOf('/')) {
            throw new Error(`Expected a tagged image for ${target}: ${ref}`);
        }
        const image = ref.slice(0, separator);
        if (!images.has(image)) images.set(image, new Set());
        images.get(image).add(ref.slice(separator + 1));
    }
    const tags = [...images.values()][0];
    // metadata-action applies every tag to every image; reject a lossy mapping.
    for (const imageTags of images.values()) {
        if (imageTags.size !== tags.size || [...tags].some(tag => !imageTags.has(tag))) {
            throw new Error(`Bake target ${target} has different tags per registry`);
        }
    }
    return {
        target,
        images: [...images.keys()].join('\n'),
        tags: [...tags].map(tag => `type=raw,value=${tag}`).join('\n'),
    };
});

if (include.length === 0) throw new Error('Bake returned no targets');
process.stdout.write(JSON.stringify({ include }) + '\n');
