<?php

$_SERVER['GITHUB_REF'] ??= 'refs/heads/main';
$_SERVER['GITHUB_RUN_ID'] ??= '1';

function get_digest_of_image(string $imageName, string $tag): string {
    $response = json_decode(file_get_contents('https://hub.docker.com/v2/repositories/' . $imageName . '/tags/?page_size=50&page=1&name=' . urlencode($tag)), true);
    $digest = null;
    foreach ($response['results'] as $image) {
        if ($image['name'] === $tag) {
            $digest = $image['digest'];
            break;
        }
    }

    if (empty($digest)) {
        throw new \Exception('Cannot find digest of ' . $imageName . ':' . $tag);
    }

    return $digest;
}

$supportedVersions = ['8.1', '8.2', '8.3'];
$disallowedVersions = ['8.2.20', '8.3.8'];
$rcVersions = [];

$data = [];

$versionRegex ='/^(?<version>\d\.\d\.\d{1,}(RC\d)?)/m';


foreach ($supportedVersions as $supportedVersion)
{

    $curVersion = null;
    $patchVersion = null;
    $rcVersion = null;

    $page = 0;

    do {
        $apiResponse = json_decode(file_get_contents('https://hub.docker.com/v2/repositories/library/php/tags/?page_size=50&page=' . $page . '&name=' . $supportedVersion. '.'), true);

        if (!is_array($apiResponse)) {
            throw new \RuntimeException("invalid api response");
        }

        foreach ($apiResponse['results'] as $entry) {
            preg_match($versionRegex, $entry['name'], $rcVersion);

            if (strpos($entry['name'], 'RC') !== false && !in_array($rcVersion['version'], $rcVersions)) {
                continue;
            }

            if (preg_match($versionRegex, $entry['name'], $patchVersion)) {
                if (in_array($patchVersion['version'], $disallowedVersions, true)) {
                    $patchVersion = null;
                    continue;
                }

                break;
            }
        }

        if ($patchVersion !== null) {
            break;
        }

    } while($page++ < 5);

    if ($patchVersion === null) {
        throw new \RuntimeException('There is no version found for PHP ' . $supportedVersion);
    }

    $phpDigest = get_digest_of_image('library/php', $patchVersion['version'] . '-fpm-alpine');

    $imageTagPrefix = $_SERVER['GITHUB_REF'] !== 'refs/heads/main' ? ($_SERVER['GITHUB_RUN_ID'] . '-') : '';

    $imageSuffix = $_SERVER['GITHUB_REF'] !== 'refs/heads/main' ? '-ci-test' : '';

    $caddyImages = [
        'ghcr.io/shopware/docker-base' . $imageSuffix . ':' . $imageTagPrefix . $supportedVersion,
        'ghcr.io/shopware/docker-base' . $imageSuffix . ':' . $imageTagPrefix . $supportedVersion . '-caddy',
        'ghcr.io/shopware/docker-base' . $imageSuffix . ':' . $imageTagPrefix . $patchVersion['version'],
        'ghcr.io/shopware/docker-base' . $imageSuffix . ':' . $imageTagPrefix . $patchVersion['version'] . '-caddy',
    ];

    $caddyImagesOtel = [
        'ghcr.io/shopware/docker-base' . $imageSuffix . ':' . $imageTagPrefix . $supportedVersion . '-caddy-otel',
        'ghcr.io/shopware/docker-base' . $imageSuffix . ':' . $imageTagPrefix . $patchVersion['version'] . '-caddy-otel',
    ];

    $nginxImages = [
        'ghcr.io/shopware/docker-base' . $imageSuffix . ':' . $imageTagPrefix . $supportedVersion . '-nginx',
        'ghcr.io/shopware/docker-base' . $imageSuffix . ':' . $imageTagPrefix . $patchVersion['version'] . '-nginx',
    ];
    
    $nginxImagesOtel = [
        'ghcr.io/shopware/docker-base' . $imageSuffix . ':' . $imageTagPrefix . $supportedVersion . '-nginx-otel',
        'ghcr.io/shopware/docker-base' . $imageSuffix . ':' . $imageTagPrefix . $patchVersion['version'] . '-nginx-otel',
    ];

    $fpmImages = [
        'ghcr.io/shopware/docker-base' . $imageSuffix . ':' . $imageTagPrefix . $supportedVersion . '-fpm',
        'ghcr.io/shopware/docker-base' . $imageSuffix . ':'  . $imageTagPrefix . $patchVersion['version'] . '-fpm'
    ];

    $fpmImagesOtel = [
        'ghcr.io/shopware/docker-base' . $imageSuffix . ':' . $imageTagPrefix . $supportedVersion . '-fpm-otel',
        'ghcr.io/shopware/docker-base' . $imageSuffix . ':'  . $imageTagPrefix . $patchVersion['version'] . '-fpm-otel'
    ];

    if ($_SERVER['GITHUB_REF'] === 'refs/heads/main') {
        $caddyImages = array_merge($caddyImages, [
            'shopware/docker-base:' . $imageTagPrefix . $supportedVersion,
            'shopware/docker-base:' . $imageTagPrefix . $supportedVersion . '-caddy',
            'shopware/docker-base:' . $imageTagPrefix . $patchVersion['version'],
            'shopware/docker-base:' . $imageTagPrefix . $patchVersion['version'] . '-caddy',
        ]);

        $caddyImagesOtel = array_merge($caddyImagesOtel, [
            'shopware/docker-base:' . $imageTagPrefix . $supportedVersion . '-caddy-otel',
            'shopware/docker-base:' . $imageTagPrefix . $patchVersion['version'] . '-caddy-otel',
        ]);

        $nginxImages = array_merge($nginxImages, [
            'shopware/docker-base:' . $imageTagPrefix . $supportedVersion . '-nginx',
            'shopware/docker-base:' . $imageTagPrefix . $patchVersion['version'] . '-nginx',
        ]);

        $nginxImagesOtel = array_merge($nginxImagesOtel, [
            'shopware/docker-base:' . $imageTagPrefix . $supportedVersion . '-nginx-otel',
            'shopware/docker-base:' . $imageTagPrefix . $patchVersion['version'] . '-nginx-otel',
        ]);

        $fpmImages = array_merge($fpmImages, [
            'shopware/docker-base:' . $imageTagPrefix . $supportedVersion . '-fpm',
            'shopware/docker-base:' . $imageTagPrefix . $patchVersion['version'] . '-fpm'
        ]);

        $fpmImagesOtel = array_merge($fpmImagesOtel, [
            'shopware/docker-base:' . $imageTagPrefix . $supportedVersion . '-fpm-otel',
            'shopware/docker-base:' . $imageTagPrefix . $patchVersion['version'] . '-fpm-otel'
        ]);
    }

    $data[] = [
        'php' => $supportedVersion,
        'phpPatch' => $patchVersion['version'],
        'phpPatchDigest' => $phpDigest,
        'fpm-image' => 'ghcr.io/shopware/docker-base' . $imageSuffix . ':' . $imageTagPrefix . $supportedVersion . '-fpm',
        'fpm-tags' => implode("\n", $fpmImages),
        'fpm-tags-otel' => implode("\n", $fpmImagesOtel),
        'caddy-tags' => implode("\n", $caddyImages),
        'caddy-tags-otel' => implode("\n", $caddyImagesOtel),
        'nginx-tags' => implode("\n", $nginxImages),
        'nginx-tags-otel' => implode("\n", $nginxImagesOtel),
        'scan-tag' => $caddyImages[0],
        'scan-to' => 'ghcr.io/shopware/docker-base:'.$supportedVersion,
    ];
}

echo json_encode(['matrix' => ['include' => $data]], JSON_THROW_ON_ERROR);
