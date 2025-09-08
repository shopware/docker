<?php

use Scripts\Boot\ScriptKernel;
use Shopware\Core\Framework\Adapter\Kernel\KernelFactory;
use Shopware\Core\Framework\Plugin\KernelPluginLoader\StaticKernelPluginLoader;
use Symfony\Component\HttpKernel\KernelInterface;
use Shopware\Core\HttpKernel;

$classLoader = require '/var/www/html/vendor/autoload.php';

require __DIR__ . '/ScriptKernel.php';

$projectRoot = dirname(__DIR__) . '/../../';

$env = $env ?? 'dev';

if (class_exists(KernelFactory::class)) {
    /** @var KernelInterface $kernel */
    KernelFactory::$kernelClass = ScriptKernel::class;
    $kernel = KernelFactory::create(
        environment: $env,
        debug: true,
        classLoader: $classLoader
    );

    $kernel->boot();
} else {
    $kernel = new class($env, $env !== 'prod', $classLoader) extends HttpKernel {
        protected static string $kernelClass = ScriptKernel::class;
    };

    $kernel->getKernel()->boot();
}

return $kernel;
