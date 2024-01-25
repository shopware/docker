<?php

require __DIR__ . '/functions.php';

$supportedVersions = ['8.1', '8.2', '8.3'];
$rcVersions = [];

$data = [];

$versionRegex ='/^(?<version>\d\.\d\.\d{1,}(RC\d)?)/m';

$supervisord = get_digest_of_image('shyim/supervisord', 'latest');

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

    $data[] = [
        'php' => $supportedVersion,
        'phpPatch' => $patchVersion['version'],
        'phpPatchDigest' => $phpDigest,
        'supervisordDigest' => $supervisord,
        'fpm-image' => 'ghcr.io/shopware/docker-base:' . $supportedVersion . '-fpm',
        'fpm-patch-image' => 'ghcr.io/shopware/docker-base:' . $patchVersion['version'] . '-fpm',
        'fpm-hub-image' => 'shopware/docker-base:' . $supportedVersion . '-fpm',
        'fpm-patch-hub-image' => 'shopware/docker-base:' . $patchVersion['version'] . '-fpm',
    ];
}

echo json_encode(['matrix' => ['include' => $data]], JSON_THROW_ON_ERROR);
