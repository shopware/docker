import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

// Docker GitHub Builder publishes the Cartesian product of images and tags.
// Resolve one output target and reject tag sets that would change that product.
export function getMetadata(definition, requestedTarget) {
    const targets = definition.group?.[requestedTarget]?.targets ?? [requestedTarget];
    if (targets.length !== 1) {
        throw new Error(`Expected one output target for ${requestedTarget}, found ${targets.length}`);
    }

    const target = targets[0];
    const tags = definition.target?.[target]?.tags;
    if (!tags?.length) {
        throw new Error(`No image tags found for ${target}`);
    }

    const images = new Map();
    for (const reference of tags) {
        const match = reference.match(/^([a-z0-9._:/-]+):([\w][\w.-]{0,127})$/);
        if (!match) {
            throw new Error(`Invalid tagged image reference: ${reference}`);
        }
        const [, image, tag] = match;
        if (!images.has(image)) {
            images.set(image, new Set());
        }
        images.get(image).add(tag);
    }

    const tagNames = [...images.values().next().value];
    for (const imageTags of images.values()) {
        if (imageTags.size !== tagNames.length || tagNames.some(tag => !imageTags.has(tag))) {
            throw new Error(`Registries must have the same tags for ${target}`);
        }
    }

    return {
        target,
        images: [...images.keys()].join('\n'),
        tags: tagNames.map(tag => `type=raw,value=${tag}`).join('\n'),
    };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
    const definition = JSON.parse(readFileSync(0, 'utf8'));
    console.log(`metadata=${JSON.stringify(getMetadata(definition, process.argv[2]))}`);
}
