<?php

require __DIR__ . '/functions.php';

$supportedVersions = ['8.0', '8.1', '8.2', '8.3'];
$rcVersions = ['8.3.0RC5'];

$index = [];
$tpl = file_get_contents('Dockerfile.template');
$versionRegex ='/^(?<version>\d\.\d\.\d{1,}(RC\d)?)/m';

$caddyDigest = get_digest_of_image('library/caddy', 'latest');

$workflow = <<<YML
name: Build
on:
  workflow_dispatch:
  push:
    branches:
      - main
      - hydro-build
    paths:
      - "Dockerfile.template"
      - ".github/workflows/build.yml"
      - "rootfs/**"

env:
  DOCKER_BUILDKIT: 1
  COSIGN_EXPERIMENTAL: 1

permissions:
  contents: write
  id-token: write
  packages: write

jobs:
YML;

$stages = [];
$dockerMerges = [];

foreach ($supportedVersions as $supportedVersion)
{
    $apiResponse = json_decode(file_get_contents('https://hub.docker.com/v2/repositories/library/php/tags/?page_size=50&page=1&name=' . $supportedVersion. '.'), true);

    if (!is_array($apiResponse)) {
        throw new \RuntimeException("invalid api response");
    }

    $curVersion = null;
    $patchVersion = null;
    $rcVersion = null;

    foreach ($apiResponse['results'] as $entry) {
        preg_match($versionRegex, $entry['name'], $rcVersion);

        if (strpos($entry['name'], 'RC') !== false && !in_array($rcVersion['version'], $rcVersions)) {
            continue;
        }

        preg_match($versionRegex, $entry['name'], $patchVersion);
    }

    if ($patchVersion === null) {
        throw new \RuntimeException('There is no version found for PHP ' . $supportedVersion);
    }

    $phpDigest = get_digest_of_image('library/php', $patchVersion['version'] . '-fpm-alpine');

    $folder = $supportedVersion . '/';
    if (!file_exists($folder)) {
        mkdir($folder, 0777, true);
    }

    $phpShort = str_replace('.', '', $supportedVersion);
    $replaces = [
      '${PHP_VERSION_SHORT}' => $phpShort,
      '${PHP_VERSION}' => $supportedVersion,
      '${PHP_PATCH_VERSION}' => $patchVersion['version'],
      '${PHP_DIGEST}' => $phpDigest,
      '${CADDY_DIGEST}' => $caddyDigest,
    ];

    file_put_contents($folder . 'Dockerfile', str_replace(array_keys($replaces), array_values($replaces), $tpl));

    exec('rm -rf ' . $folder . '/rootfs');
    exec('cp -R rootfs ' . $folder . '/rootfs');

    $index[$supportedVersion] = $patchVersion['version'];

    $workflowTpl = <<<'TPL'

  php${PHP_VERSION_SHORT}:
      name: ${PHP_VERSION}
      runs-on: ubuntu-22.04
      steps:
        - uses: actions/checkout@v3

        - name: Install Cosign
          uses: sigstore/cosign-installer@v3
  
        - name: Login into Github Docker Registery
          run: echo "${{ secrets.GITHUB_TOKEN }}" | docker login ghcr.io -u ${{ github.actor }} --password-stdin
  
        - name: Log in to Docker Hub
          uses: docker/login-action@v3
          with:
            username: ${{ secrets.DOCKER_HUB_USERNAME }}
            password: ${{ secrets.DOCKER_HUB_PASSWORD }}

        - name: Set up Docker Buildx
          uses: docker/setup-buildx-action@v3
          with:
            version: "lab:latest"
            driver: cloud
            endpoint: "shopware/default"
  
        - uses: docker/build-push-action@v5
          with:
            tags: ghcr.io/shopware/docker-base-hydro:${PHP_PATCH_VERSION}
            context: "${PHP_VERSION}"
            platforms: linux/amd64,linux/arm64
            push: true
            provenance: false
  
TPL;

    $workflow .= str_replace(array_keys($replaces), array_values($replaces), $workflowTpl);
}

file_put_contents('.github/workflows/build.yml', $workflow);
