<?php

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