<?php

$supportedVersions = ['8.0', '8.1', '8.2'];
$index = [];
$tpl = file_get_contents('Dockerfile.template');
$versionRegex ='/^(?<version>\d\.\d\.\d{1,})/m';

$workflow = <<<YML
name: Build
on:
  workflow_dispatch:
  push:
    branches:
      - main
    paths:
      - "Dockerfile.template"
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

    foreach ($apiResponse['results'] as $entry) {
        if (strpos($entry['name'], 'RC') !== false) {
            continue;
        }

        preg_match($versionRegex, $entry['name'], $patchVersion);

        if (count($patchVersion) > 0) {
            break;
        }
    }

    if ($patchVersion === null) {
        throw new \RuntimeException('There is no version found for PHP ' . $supportedVersion);
    }

    $folder = $supportedVersion . '/';
    if (!file_exists($folder)) {
        mkdir($folder, 0777, true);
    }

    file_put_contents($folder . 'Dockerfile', str_replace('${PHP_VERSION}', $patchVersion['version'], $tpl));

    exec('rm -rf ' . $folder . '/rootfs');
    exec('cp -R rootfs ' . $folder . '/rootfs');

    $index[$supportedVersion] = $patchVersion['version'];

    $workflowTpl = <<<'TPL'

  php${PHP_VERSION_SHORT}-arm64:
    name: ${PHP_VERSION} on ARM64
    runs-on: buildjet-2vcpu-ubuntu-2204-arm
    steps:
      - uses: actions/checkout@v3

      - name: Install Cosign
        uses: sigstore/cosign-installer@v3
  
      - name: Login into Github Docker Registery
        run: echo "${{ secrets.GITHUB_TOKEN }}" | docker login ghcr.io -u ${{ github.actor }} --password-stdin

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - uses: docker/build-push-action@v4
        with:
          tags: ghcr.io/friendsofshopware/production-docker-base:${PHP_PATCH_VERSION}-arm64
          context: "${PHP_VERSION}"
          cache-from: type=registry,ref=ghcr.io/friendsofshopware/production-docker-cache:${PHP_VERSION}-arm64
          cache-to: type=registry,ref=ghcr.io/friendsofshopware/production-docker-cache:${PHP_VERSION}-arm64,mode=max
          platforms: linux/arm64
          push: true
          provenance: false

  php${PHP_VERSION_SHORT}-amd64:
      name: ${PHP_VERSION} on AMD64
      runs-on: ubuntu-22.04
      steps:
        - uses: actions/checkout@v3

        - name: Install Cosign
          uses: sigstore/cosign-installer@v3
  
        - name: Login into Github Docker Registery
          run: echo "${{ secrets.GITHUB_TOKEN }}" | docker login ghcr.io -u ${{ github.actor }} --password-stdin
  
        - name: Set up Docker Buildx
          uses: docker/setup-buildx-action@v2
  
        - uses: docker/build-push-action@v4
          with:
            tags: ghcr.io/friendsofshopware/production-docker-base:${PHP_PATCH_VERSION}-amd64
            context: "${PHP_VERSION}"
            cache-from: type=registry,ref=ghcr.io/friendsofshopware/production-docker-cache:${PHP_VERSION}-amd64
            cache-to: type=registry,ref=ghcr.io/friendsofshopware/production-docker-cache:${PHP_VERSION}-amd64,mode=max
            platforms: linux/amd64
            push: true
            provenance: false
  
TPL;

    $phpShort = str_replace('.', '', $supportedVersion);
    $replaces = [
      '${PHP_VERSION_SHORT}' => $phpShort,
      '${PHP_VERSION}' => $supportedVersion,
      '${PHP_PATCH_VERSION}' => $patchVersion['version'],
    ];

    $workflow .= str_replace(array_keys($replaces), array_values($replaces), $workflowTpl);

    $dockerMerges[] = 'docker manifest create ghcr.io/friendsofshopware/production-docker-base:' . $supportedVersion . ' --amend ghcr.io/friendsofshopware/production-docker-base:' . $patchVersion['version'] . '-amd64 --amend ghcr.io/friendsofshopware/production-docker-base:' . $patchVersion['version'] . '-arm64';
    $dockerMerges[] = 'docker manifest create ghcr.io/friendsofshopware/production-docker-base:' . $patchVersion['version'] . ' --amend ghcr.io/friendsofshopware/production-docker-base:' . $patchVersion['version'] . '-amd64 --amend ghcr.io/friendsofshopware/production-docker-base:' . $patchVersion['version'] . '-arm64';
    $dockerMerges[] = 'docker manifest push ghcr.io/friendsofshopware/production-docker-base:' . $supportedVersion;
    $dockerMerges[] = 'docker manifest push ghcr.io/friendsofshopware/production-docker-base:' . $patchVersion['version'];

    $dockerMerges[] = 'cosign sign --yes ghcr.io/friendsofshopware/production-docker-base:' . $supportedVersion;
    $dockerMerges[] = 'cosign sign --yes ghcr.io/friendsofshopware/production-docker-base:' . $patchVersion['version'];

    $stages[] = 'php' . $phpShort . '-arm64';
    $stages[] = 'php' . $phpShort . '-amd64';
}

$workflow .= '

  merge-manifest:
    name: Merge Manifest
    runs-on: ubuntu-22.04
    needs:
';

foreach ($stages as $stage) {
  $workflow .= '      - ' . $stage . "\n";
}

$workflow .= '
    steps:
      - name: Login into Github Docker Registery
        run: echo "${{ secrets.GITHUB_TOKEN }}" | docker login ghcr.io -u ${{ github.actor }} --password-stdin

      - name: Install Cosign
        uses: sigstore/cosign-installer@v3

';

foreach ($dockerMerges as $merge) {
  $workflow .= "      - run: " . $merge . "\n\n";
}

file_put_contents('.github/workflows/build.yml', $workflow);