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

function node_version_suffix(?string $nodeVersion): string {
    if ($nodeVersion === null) {
        return '';
    }

    return '-node-' . $nodeVersion;
}

$supportedVersions = ['8.1', '8.2', '8.3', '8.4'];
$disallowedVersions = ['8.2.20', '8.3.8'];
$rcVersions = [];

$supportedNodeVersions = [
    '8.1' => [
        null,
    ],
    '8.2' => [
        null,
    ],
    '8.3' => [
        null,
        '22',
    ],
    '8.4' => [
        null,
        '22',
        '24',
    ],
];

$data = [];

$versionRegex ='/^(?<version>\d\.\d\.\d{1,}(RC\d)?)/m';

foreach ($supportedVersions as $supportedVersion) {
    foreach ($supportedNodeVersions[$supportedVersion] as $supportedNodeVersion) {
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
            'ghcr.io/shopware/docker-base' . $imageSuffix . ':' . $imageTagPrefix . $supportedVersion . node_version_suffix($supportedNodeVersion),
            'ghcr.io/shopware/docker-base' . $imageSuffix . ':' . $imageTagPrefix . $supportedVersion . node_version_suffix($supportedNodeVersion) . '-caddy',
            'ghcr.io/shopware/docker-base' . $imageSuffix . ':' . $imageTagPrefix . $patchVersion['version'] . node_version_suffix($supportedNodeVersion),
            'ghcr.io/shopware/docker-base' . $imageSuffix . ':' . $imageTagPrefix . $patchVersion['version'] . node_version_suffix($supportedNodeVersion) . '-caddy',
        ];

        $caddyImagesOtel = [
            'ghcr.io/shopware/docker-base' . $imageSuffix . ':' . $imageTagPrefix . $supportedVersion . node_version_suffix($supportedNodeVersion) . '-caddy-otel',
            'ghcr.io/shopware/docker-base' . $imageSuffix . ':' . $imageTagPrefix . $patchVersion['version'] . node_version_suffix($supportedNodeVersion) . '-caddy-otel',
        ];

        $nginxImages = [
            'ghcr.io/shopware/docker-base' . $imageSuffix . ':' . $imageTagPrefix . $supportedVersion . node_version_suffix($supportedNodeVersion) . '-nginx',
            'ghcr.io/shopware/docker-base' . $imageSuffix . ':' . $imageTagPrefix . $patchVersion['version'] . node_version_suffix($supportedNodeVersion) . '-nginx',
        ];

        $nginxImagesOtel = [
            'ghcr.io/shopware/docker-base' . $imageSuffix . ':' . $imageTagPrefix . $supportedVersion . node_version_suffix($supportedNodeVersion) . '-nginx-otel',
            'ghcr.io/shopware/docker-base' . $imageSuffix . ':' . $imageTagPrefix . $patchVersion['version'] . node_version_suffix($supportedNodeVersion) . '-nginx-otel',
        ];

        $frankenphpImages = [
            'ghcr.io/shopware/docker-base' . $imageSuffix . ':' . $imageTagPrefix . $supportedVersion . node_version_suffix($supportedNodeVersion) . '-frankenphp',
            'ghcr.io/shopware/docker-base' . $imageSuffix . ':'  . $imageTagPrefix . $patchVersion['version'] . node_version_suffix($supportedNodeVersion) . '-frankenphp'
        ];

        $frankenphpImagesOtel = [
            'ghcr.io/shopware/docker-base' . $imageSuffix . ':' . $imageTagPrefix . $supportedVersion . node_version_suffix($supportedNodeVersion) . '-frankenphp-otel',
            'ghcr.io/shopware/docker-base' . $imageSuffix . ':'  . $imageTagPrefix . $patchVersion['version'] . node_version_suffix($supportedNodeVersion) . '-frankenphp-otel'
        ];

        $fpmImages = [
            'ghcr.io/shopware/docker-base' . $imageSuffix . ':' . $imageTagPrefix . $supportedVersion . node_version_suffix($supportedNodeVersion) . '-fpm',
            'ghcr.io/shopware/docker-base' . $imageSuffix . ':'  . $imageTagPrefix . $patchVersion['version'] . node_version_suffix($supportedNodeVersion) . '-fpm'
        ];

        $fpmImagesOtel = [
            'ghcr.io/shopware/docker-base' . $imageSuffix . ':' . $imageTagPrefix . $supportedVersion . node_version_suffix($supportedNodeVersion) . '-fpm-otel',
            'ghcr.io/shopware/docker-base' . $imageSuffix . ':'  . $imageTagPrefix . $patchVersion['version'] . node_version_suffix($supportedNodeVersion) . '-fpm-otel'
        ];

        if ($_SERVER['GITHUB_REF'] === 'refs/heads/main') {
            $caddyImages = array_merge($caddyImages, [
                'shopware/docker-base:' . $imageTagPrefix . $supportedVersion . node_version_suffix($supportedNodeVersion),
                'shopware/docker-base:' . $imageTagPrefix . $supportedVersion . node_version_suffix($supportedNodeVersion) . '-caddy',
                'shopware/docker-base:' . $imageTagPrefix . $patchVersion['version'] . node_version_suffix($supportedNodeVersion),
                'shopware/docker-base:' . $imageTagPrefix . $patchVersion['version'] . node_version_suffix($supportedNodeVersion) . '-caddy',
            ]);

            $caddyImagesOtel = array_merge($caddyImagesOtel, [
                'shopware/docker-base:' . $imageTagPrefix . $supportedVersion . node_version_suffix($supportedNodeVersion) . '-caddy-otel',
                'shopware/docker-base:' . $imageTagPrefix . $patchVersion['version'] . node_version_suffix($supportedNodeVersion) . '-caddy-otel',
            ]);

            $nginxImages = array_merge($nginxImages, [
                'shopware/docker-base:' . $imageTagPrefix . $supportedVersion . node_version_suffix($supportedNodeVersion) . '-nginx',
                'shopware/docker-base:' . $imageTagPrefix . $patchVersion['version'] . node_version_suffix($supportedNodeVersion) . '-nginx',
            ]);

            $nginxImagesOtel = array_merge($nginxImagesOtel, [
                'shopware/docker-base:' . $imageTagPrefix . $supportedVersion . node_version_suffix($supportedNodeVersion) . '-nginx-otel',
                'shopware/docker-base:' . $imageTagPrefix . $patchVersion['version'] . node_version_suffix($supportedNodeVersion) . '-nginx-otel',
            ]);

            $fpmImages = array_merge($fpmImages, [
                'shopware/docker-base:' . $imageTagPrefix . $supportedVersion . node_version_suffix($supportedNodeVersion) . '-fpm',
                'shopware/docker-base:' . $imageTagPrefix . $patchVersion['version'] . node_version_suffix($supportedNodeVersion) . '-fpm'
            ]);

            $fpmImagesOtel = array_merge($fpmImagesOtel, [
                'shopware/docker-base:' . $imageTagPrefix . $supportedVersion . node_version_suffix($supportedNodeVersion) . '-fpm-otel',
                'shopware/docker-base:' . $imageTagPrefix . $patchVersion['version'] . node_version_suffix($supportedNodeVersion) . '-fpm-otel'
            ]);

            $frankenphpImages = array_merge($frankenphpImages, [
                'shopware/docker-base:' . $imageTagPrefix . $supportedVersion . node_version_suffix($supportedNodeVersion) . '-frankenphp',
                'shopware/docker-base:' . $imageTagPrefix . $patchVersion['version'] . node_version_suffix($supportedNodeVersion) . '-frankenphp'
            ]);

            $frankenphpImagesOtel = array_merge($frankenphpImagesOtel, [
                'shopware/docker-base:' . $imageTagPrefix . $supportedVersion . node_version_suffix($supportedNodeVersion) . '-frankenphp-otel',
                'shopware/docker-base:' . $imageTagPrefix . $patchVersion['version'] . node_version_suffix($supportedNodeVersion) . '-frankenphp-otel'
            ]);
        }

        $redisModule = 'redis';
        if (version_compare($patchVersion['version'], '8.4', '<')) {
            $redisModule = 'redis-6.0.2';
        }

        $manifestMergeScript = '';

        foreach($fpmImages as $fpmImage) {
            $manifestMergeScript .= 'docker manifest create ' . $fpmImage . ' ' . $fpmImage . '-amd64 ' . $fpmImage . '-arm64' . "\n";
            $manifestMergeScript .= 'docker manifest push ' . $fpmImage . "\n";
        }

        $manifestMergeScriptFrankenphp = '';
        foreach($frankenphpImages as $frankenphpImage) {
            $manifestMergeScriptFrankenphp .= 'docker manifest create ' . $frankenphpImage . ' ' . $frankenphpImage . '-amd64 ' . $frankenphpImage . '-arm64' . "\n";
            $manifestMergeScriptFrankenphp .= 'docker manifest push ' . $frankenphpImage . "\n";
        }

        $data[] = [
            'php' => $supportedVersion,
            'phpPatch' => $patchVersion['version'],
            'phpPatchDigest' => $phpDigest,
            'node' => $supportedNodeVersion ?? '',
            'frankenphp-image' => 'ghcr.io/shopware/docker-base' . $imageSuffix . ':' . $imageTagPrefix . $supportedVersion . node_version_suffix($supportedNodeVersion) . '-frankenphp',
            'frankenphp-merge' => $manifestMergeScriptFrankenphp,
            'frankenphp-tags-amd64' => implode("\n", array_map(fn($tag) => $tag . '-amd64', $frankenphpImages)),
            'frankenphp-tags-arm64' => implode("\n", array_map(fn($tag) => $tag . '-arm64', $frankenphpImages)),
            'frankenphp-tags-otel' => implode("\n", $frankenphpImagesOtel),
            'fpm-image' => 'ghcr.io/shopware/docker-base' . $imageSuffix . ':' . $imageTagPrefix . $supportedVersion . node_version_suffix($supportedNodeVersion) . '-fpm',
            'fpm-tags' => implode("\n", $fpmImages),
            'fpm-merge' => $manifestMergeScript,
            'fpm-tags-amd64' => implode("\n", array_map(fn($tag) => $tag . '-amd64', $fpmImages)),
            'fpm-tags-arm64' => implode("\n", array_map(fn($tag) => $tag . '-arm64', $fpmImages)),
            'fpm-tags-otel' => implode("\n", $fpmImagesOtel),
            'caddy-tags' => implode("\n", $caddyImages),
            'caddy-tags-otel' => implode("\n", $caddyImagesOtel),
            'nginx-tags' => implode("\n", $nginxImages),
            'nginx-tags-otel' => implode("\n", $nginxImagesOtel),
            'scan-tag' => $caddyImages[0],
            'scan-to' => 'ghcr.io/shopware/docker-base:' . $supportedVersion . node_version_suffix($supportedNodeVersion),
            'redisPHPModule' => $redisModule,
        ];
    }
}

echo json_encode(['matrix' => ['include' => $data]], JSON_THROW_ON_ERROR);
