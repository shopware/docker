import fs from 'node:fs/promises';

export const bakeFilePath = 'docker-bake.hcl';

export async function readBakeFile() {
    return fs.readFile(bakeFilePath, 'utf8');
}

export function readStringVariable(hclContent, name) {
    const match = hclContent.match(new RegExp(`variable "${name}" \\{\\s*default = "([^"]*)"\\s*\\}`, 's'));
    if (!match) {
        throw new Error(`${name} variable not found in ${bakeFilePath}`);
    }

    return match[1];
}

export function readListVariable(hclContent, name) {
    const match = hclContent.match(new RegExp(`variable "${name}" \\{\\s*default = \\[([^\\]]*)\\]\\s*\\}`, 's'));
    if (!match) {
        throw new Error(`${name} variable not found in ${bakeFilePath}`);
    }

    return [...match[1].matchAll(/"([^"]*)"/g)].map(([, value]) => value);
}

export function replaceVariable(hclContent, name, value) {
    const regex = new RegExp(`(variable "${name}" \\{\\s*default = )(\\[[^\\]]*\\]|"[^"]*")(\\s*\\})`, 's');

    if (!regex.test(hclContent)) {
        throw new Error(`${name} variable not found in ${bakeFilePath}`);
    }

    return hclContent.replace(regex, `$1${value}$3`);
}
