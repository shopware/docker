#!/usr/bin/env node
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmod, mkdir, mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

function docker(args, allowFailure = false) {
    if (args[0] === 'run' && process.env.LOCAL_PLATFORM) {
        args = ['run', '--platform', process.env.LOCAL_PLATFORM, ...args.slice(1)];
    }
    const result = spawnSync('docker', args, { encoding: 'utf8', maxBuffer: 8 * 1024 * 1024 });
    if (result.error) throw result.error;
    if (!allowFailure && result.status !== 0) throw new Error(`docker ${args.join(' ')}\n${result.stdout}\n${result.stderr}`);
    return result;
}
const images = process.argv.slice(2);
assert(images.length, 'Pass one or more locally built image tags');
const root = await mkdtemp(join(tmpdir(), 'shopware-runtime-test-'));
await chmod(root, 0o755);
await mkdir(join(root, 'public', 'media'), { recursive: true });
await writeFile(join(root, 'public', 'index.php'), '<?php header("Content-Type: text/plain"); echo "runtime-ok:" . PHP_VERSION;');
await writeFile(join(root, 'public', 'media', 'test.svg'), '<svg xmlns="http://www.w3.org/2000/svg"/>');

try {
    for (const image of images) {
        const dev = image.includes('-dev-');
        const otel = dev || image.includes('-otel-');
        const frankenphp = image.includes('frankenphp');
        const config = JSON.parse(docker(['image', 'inspect', image]).stdout)[0].Config;
        assert.equal(config.User, 'www-data', image);
        assert.equal(config.WorkingDir, '/var/www/html', image);
        assert.equal(docker(['run', '--rm', '--entrypoint', 'id', image, '-u']).stdout.trim(), dev ? '1000' : '82');
        const code = `
            $required = ['bcmath','gd','intl','mysqli','pdo_mysql','pcntl','sockets','bz2','gmp','soap','zip','ftp','FFI','Zend OPcache','xsl','redis','apcu','zstd','amqp'];
            foreach ($required as $ext) if (!extension_loaded($ext)) throw new Exception("Missing " . $ext);
            if (PHP_VERSION !== getenv('PHP_VERSION')) throw new Exception('PHP version mismatch');
            if (extension_loaded('grpc') !== ${otel ? 'true' : 'false'}) throw new Exception('gRPC mismatch');
            if (extension_loaded('opentelemetry') !== ${otel && !dev ? 'true' : 'false'}) throw new Exception('OTel mismatch');
            if ((bool) PHP_ZTS !== ${frankenphp ? 'true' : 'false'}) throw new Exception('Thread safety mismatch');
            foreach (['xdebug','tideways','blackfire','spx'] as $ext) {
                if (extension_loaded($ext)) throw new Exception('Profiler unexpectedly enabled: ' . $ext);
                if (!${frankenphp ? 'true' : 'false'} && !is_file(ini_get('extension_dir') . '/' . $ext . '.so')) throw new Exception('Missing profiler binary: ' . $ext);
            }
            foreach (['grpc','opentelemetry'] as $ext) {
                if (!is_file(ini_get('extension_dir') . '/' . $ext . '.so')) throw new Exception('Missing optional extension: ' . $ext);
            }

            $im = imagecreatetruecolor(8, 8);
            if (!imagewebp($im, '/tmp/runtime-test.webp')) throw new Exception('WebP failed');
            if (!(new IntlDateFormatter('de_DE', 0, 0))->format(0)) throw new Exception('ICU failed');
            if (zstd_uncompress(zstd_compress('test')) !== 'test') throw new Exception('zstd failed');
            if (bzdecompress(bzcompress('test')) !== 'test') throw new Exception('bz2 failed');
            if (strlen(sodium_crypto_generichash('test')) !== 32) throw new Exception('sodium failed');
            echo 'extensions-ok';
        `;
        const php = docker(['run', '--rm', '--entrypoint', 'php', image, '-d', 'display_errors=1', '-d', 'log_errors=0', '-r', code]);
        assert.equal(php.stdout.trim(), 'extensions-ok', image);
        assert.equal(php.stderr, '', image);
        const linkage = docker(['run', '--rm', '--entrypoint', 'sh', image, '-ec', `
            find /usr/local -type f \\( -perm /0111 -o -name '*.so*' \\) -exec ldd '{}' ';' > /tmp/linkage 2>/dev/null
            if grep -q 'not found' /tmp/linkage; then cat /tmp/linkage; exit 1; fi
            ! command -v gcc
            ! command -v g++
        `]);
        assert.equal(linkage.status, 0);
        docker(['run', '--rm', '--user', '0', '--entrypoint', 'sh', image, '-ec', 'docker-php-source extract; test -f /usr/src/php/configure; docker-php-source delete']);
        if (!frankenphp) docker(['run', '--rm', '--entrypoint', 'php-fpm', image, '-tt']);
        else docker(['run', '--rm', '--entrypoint', 'frankenphp', image, 'version']);

        if (dev) {
            for (const ext of ['xdebug', 'opentelemetry', 'tideways', 'blackfire', 'spx']) {
                const loaded = docker(['run', '--rm', '-e', `PHP_PROFILER=${ext}`, image, 'php', '-r', `if (!extension_loaded('${ext}')) exit(1); echo 'profiler-ok';`]);
                assert.equal(loaded.stdout.trim(), 'profiler-ok', `${image}: ${ext}`);
            }
            for (const command of [['node', '--version'], ['npm', '--version'], ['composer', '--version'], ['shopware-cli', '--version'], ['git', '--version'], ['patch', '--version'], ['supervisord', '--version']]) {
                docker(['run', '--rm', image, ...command]);
            }
            const expectedNode = image.endsWith('-22') ? 'v22.' : 'v24.';
            assert(docker(['run', '--rm', image, 'node', '--version']).stdout.startsWith(expectedNode));
        }

        if (frankenphp || image.includes('caddy') || image.includes('nginx')) {
            const container = docker(['run', '-d', '-p', '127.0.0.1::8000', '--mount', `type=bind,source=${root},target=/var/www/html,readonly`, image]).stdout.trim();
            try {
                const port = docker(['port', container, '8000/tcp']).stdout.trim().split(':').at(-1);
                let response;
                for (let attempt = 0; attempt < 120; attempt++) {
                    try {
                        response = await fetch(`http://127.0.0.1:${port}/`, { signal: AbortSignal.timeout(1000) });
                        if (response.ok) break;
                    } catch {}
                    await new Promise(resolve => setTimeout(resolve, 250));
                }
                assert(response?.ok, `HTTP startup failed: ${image}`);
                assert.match(await response.text(), /^runtime-ok:8\./);
                const media = await fetch(`http://127.0.0.1:${port}/media/test.svg`);
                assert.equal(media.status, 200);
                assert.match(media.headers.get('content-security-policy') ?? '', /script-src 'none'/);
            } catch (error) {
                console.error(docker(['logs', container], true).stderr);
                throw error;
            } finally {
                docker(['rm', '-f', container], true);
            }
        }
        console.log(`PASS ${image}: metadata, extensions, shared libraries${dev ? ', profilers and tools' : ''}${frankenphp || image.includes('caddy') || image.includes('nginx') ? ', HTTP and media headers' : ', FPM configuration'}`);
    }
} finally {
    await rm(root, { recursive: true, force: true });
}
