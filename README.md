# Shopware 6 Production Docker

This repository contains a base image with Alpine + PHP + (Caddy or Nginx), which you can use to build your docker image with your code.

[Documentation can be found here](https://developer.shopware.com/docs/guides/hosting/installation-updates/docker.html)

The Nginx, Caddy and FrankenPHP configurations send `script-src 'none'; object-src 'none'; frame-src 'none'; base-uri 'none'; form-action 'none'` for static SVG files and existing HTML files under `public/media` and `public/thumbnail`. Application-rendered HTML and bundled HTML applications retain their own response policies. Custom static documents must work without scripts, embedded documents, base URL overrides or form submissions; images and styles remain permitted. Development images inherit the corresponding server configuration.
