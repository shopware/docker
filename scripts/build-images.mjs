#!/usr/bin/env node
import { createHash } from 'node:crypto';
import { mkdtemp, readdir, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

// Local mode only writes to the local Docker daemon. Publishing is opt-in.
const argv = process.argv.slice(2);
const publish = argv.includes('--publish');
const print = argv.includes('--print');
const noCacheCompiled = argv.includes('--no-cache-compiled');
const targets = argv.filter(arg => !arg.startsWith('--'));
for (const arg of argv.filter(arg => arg.startsWith('--'))) {
    if (!['--publish', '--print', '--no-cache-compiled'].includes(arg)) {
        throw new Error(`Unknown option: ${arg}`);
    }
}
if (!targets.length) targets.push('daily');

const env = { ...process.env, compiledSource: 'local' };
const builder = process.env.BUILDX_BUILDER;
const bakeArgs = ['buildx', 'bake', ...(builder ? ['--builder', builder] : []), '-f', 'docker-bake.hcl'];
function docker(args, { capture = true, allowFailure = false, environment = env } = {}) {
    const result = spawnSync('docker', args, {
        env: environment, encoding: 'utf8', stdio: capture ? ['ignore', 'pipe', 'pipe'] : 'inherit',
        maxBuffer: 32 * 1024 * 1024,
    });
    if (result.error) throw result.error;
    if (result.status !== 0 && !allowFailure) {
        throw new Error(`docker ${args.join(' ')} failed\n${result.stderr ?? ''}`);
    }
    return result;
}
function plan(names, environment = env) {
    return JSON.parse(docker([...bakeArgs, '--print', ...names], { environment }).stdout);
}

// Hash only compilation inputs. Daily rootfs/configuration edits must not create
// new artifact tags. Include the complete matrix so separate CI jobs agree.
const compilation = plan(['compiled'], { ...env, phpMinor: '', compiledKey: 'inputs', compiledRegistry: 'inputs' });
for (const target of Object.values(compilation.target)) {
    delete target.tags;
    delete target.output;
}
const hash = createHash('sha256').update(JSON.stringify(compilation.target));
for (const file of (await readdir('compiled')).sort()) {
    hash.update(file).update(await readFile(join('compiled', file)));
}
// This variable is deliberately separate from upstream refs for forced rebuilds.
const inputPlan = plan(['_compiled-inputs']);
hash.update(inputPlan.target['_compiled-inputs'].args.COMPILED_REVISION);
const key = hash.digest('hex').slice(0, 24);
env.compiledKey = key;
const localSuffix = process.env.LOCAL_PLATFORM ? `-${process.env.LOCAL_PLATFORM.split('/')[1]}` : '';
if (!publish) env.compiledRegistry = `shopware-runtime-artifacts${localSuffix}`;

const requested = plan(targets);
const artifacts = Object.entries(requested.target).filter(([name]) => name.startsWith('artifacts-'));
const selected = new Set();
function select(name) {
    if (requested.group?.[name]) requested.group[name].targets.forEach(select);
    else selected.add(name);
}
targets.forEach(select);
const architecture = publish ? undefined : docker(['info', '--format', '{{.Architecture}}']).stdout.trim();
const platform = process.env.LOCAL_PLATFORM ?? (architecture === 'aarch64' ? 'linux/arm64' : 'linux/amd64');
const overrides = { target: {} };
for (const [name, target] of Object.entries(requested.target)) {
    overrides.target[name] = publish ? {} : { platforms: [platform] };
    if (!publish && selected.has(name)) overrides.target[name].tags = [`shopware-local${localSuffix}:${name}`];
}

if (print) {
    console.log(JSON.stringify({ key, artifacts: artifacts.map(([name, target]) => ({ name, tag: target.tags[0] })), targets: [...selected], platform: publish ? 'multi-platform' : platform }, null, 2));
    process.exit(0);
}

const work = await mkdtemp(join(tmpdir(), 'shopware-build-'));
const overrideFile = join(work, 'override.json');
try {
    await writeFile(overrideFile, JSON.stringify(overrides));
    const missing = [];
    const references = new Map();
    for (const [name, target] of artifacts) {
        const tag = target.tags[0];
        if (publish) {
            const result = docker(['buildx', 'imagetools', 'inspect', tag, '--format', '{{.Manifest.Digest}}'], { allowFailure: true });
            if (result.status === 0) references.set(name, `${tag.slice(0, tag.lastIndexOf(':'))}@${result.stdout.trim()}`);
            else if (/not found|manifest unknown|404/i.test(result.stderr)) missing.push(name);
            else throw new Error(`Cannot check artifact ${tag}: ${result.stderr}`);
        } else {
            const result = docker(['image', 'inspect', tag, '--format', '{{.Os}}/{{.Architecture}}'], { allowFailure: true });
            if (result.status === 0 && result.stdout.trim() === platform) references.set(name, tag);
            else missing.push(name);
        }
    }
    if (missing.length) {
        console.log(`Building ${missing.length} compiled artifacts (${key})`);
        docker([...bakeArgs, '-f', overrideFile, ...(noCacheCompiled ? ['--no-cache', '--pull'] : []), publish ? '--push' : '--load', ...missing], { capture: false });
        for (const name of missing) {
            const tag = requested.target[name].tags[0];
            const digest = publish ? docker(['buildx', 'imagetools', 'inspect', tag, '--format', '{{.Manifest.Digest}}']).stdout.trim() : null;
            references.set(name, publish ? `${tag.slice(0, tag.lastIndexOf(':'))}@${digest}` : tag);
        }
    } else {
        console.log(`Reusing all ${artifacts.length} compiled artifacts (${key})`);
    }
    // Replace every artifact edge with a published digest (or a local image).
    // The final build graph consequently cannot execute a compiler.
    for (const [name, target] of Object.entries(requested.target)) {
        for (const [context, value] of Object.entries(target.contexts ?? {})) {
            if (value.startsWith('target:artifacts-')) {
                overrides.target[name].contexts ??= {};
                overrides.target[name].contexts[context] = `docker-image://${references.get(value.slice('target:'.length))}`;
            }
        }
    }
    await writeFile(overrideFile, JSON.stringify(overrides));
    const dailyPlan = JSON.parse(docker([...bakeArgs, '-f', overrideFile, '--print', ...targets]).stdout);
    if (Object.keys(dailyPlan.target).some(name => /^(compiled-|artifacts-|php-fpm-|php-zts-|frankenphp-upstream)/.test(name))) {
        throw new Error('Daily build unexpectedly includes compilation targets');
    }
    // --pull would also try to fetch our local-only artifact tags from Docker Hub.
    // Pull OS bases explicitly in local mode instead.
    if (!publish) {
        const bases = new Set();
        for (const target of Object.values(dailyPlan.target)) {
            if (target.context === 'fpm') bases.add(`alpine:${target.args.ALPINE_VERSION}`);
            if (target.context === 'frankenphp') bases.add('debian:trixie-slim');
            if (target.context === 'dev') bases.add(`node:${target.args.NODE_VERSION}-alpine${target.args.ALPINE_VERSION}`);
        }
        for (const base of bases) docker(['pull', '--platform', platform, base], { capture: false });
    }
    docker([...bakeArgs, '-f', overrideFile, ...(publish ? ['--pull', '--push'] : ['--load']), ...targets], { capture: false });
    console.log(`Built ${[...selected].join(', ')} using compiled artifacts ${key}`);
} finally {
    await rm(work, { recursive: true, force: true });
}
