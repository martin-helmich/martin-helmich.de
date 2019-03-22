---
layout:     post
title:      "Well contained: Running TYPO3 in Docker"
originalDate: 2016-04-10 21:42:28 +0200
date:       2019-03-22 17:25:28 +0100
tags:       [typo3, docker]
lang:       en
image:      /assets/headers/containers.jpg
image_license: CC BY
image_author: Glyn Lowe
image_source: https://www.flickr.com/photos/glynlowe/10039742285
disqus_id: 2d781b1b-2cca-3912-9e45-81d22325ec90
permalink: /en/blog/typo3-cms-docker.html
translations:
  de: /de/blog/typo3-cms-docker.html
  en: /en/blog/typo3-cms-docker.html
---

For the 10th edition of my book *Practical Knowledge in TYPO3* (original title *Praxiswissen TYPO3*) that is going to be released end of this month, I was looking for a way to offer readers an easy quickstart with TYPO3 - for all operating systems. The Windows installers that used to circulate among the TYPO3 community are hopelessly outdated and a from-scratch installation on unixoid operating systems also had its pitfalls.

Since I've been working intensively with Docker and seeing as Docker offers an easy installation on all operating systems (thanks to the *Docker Toolbox* or *Docker for Windows*  and *Docker for macOS*, respectively), I opted to build my own Docker image for TYPO3.

{% update Update %}
  Since recently, I've also been building images for TYPO3 8.7 and 9.5. This article has been updated where necessary to reflect this.
{% endupdate %}

## First steps

The TYPO3 image is available on [Docker Hub by the repository name `martinhelmich/typo3`][hub-typo3]. You can use the `docker pull` command below to retrieve the current version of the image:

    $ docker pull martinhelmich/typo3

Furthermore, you can use the `docker pull` command to download a specific version. For this, the repository offers the following tags:

  - `martinhelmich/typo3:6` for the current 6.2 LTS version
  - `martinhelmich/typo3:7` for the current 7.6 LTS version
  - `martinhelmich/typo3:8` for the current 8.7 LTS version
  - `martinhelmich/typo3:9` or `martinhelmich/typo3:latest` for the current 9.5 LTS version

The image only contains a web server with PHP. To follow Docker's *"One container, one service"* philosophy, the database management system should best be started in its own container, for example using the `mysql` image:

    $ docker run -d --name typo3-db \
        -e MYSQL_ROOT_PASSWORD=yoursupersecretpassword \
        -e MYSQL_USER=typo3 \
        -e MYSQL_PASSWORD=yourothersupersecretpassword \
        -e MYSQL_DATABASE=typo3 \
      mysql:5.7 \
        --character-set-server=utf8 \
        --collation-server=utf8_unicode_ci

{% danger Caution %}
  Remember to replace the password placeholders in the code snippets above with secure values!
{% enddanger %}

Having a running database, you can start the actual application container:

    $ docker run -d --name typo3-web \
        --link typo3-db:db \
        -p 80:80 \
      martinhelmich/typo3:9

After that, your TYPO3 installation can be reached at `http://localhost` (in case you are using the Docker Toolbox on Windows or macOS, use the IP address of the Docker VM instead. You can determine this IP address by running the `docker-machine ip` command).

The TYPO3 running in the container is not fully installed, yet. This means that you will need to complete the Setup Wizard, first.

## Production deployment

The practice described above is more than sufficient for a demonstration, testing or development. If you want to use the `martinhelmich/typo3`image in production, there are a few more things that you should keep in mind.

In production usage, it is especially important to worry about any kind of persistent data for your TYPO3 installation. The image already contains pre-configured volumes for the four directories

  1. /var/www/html/fileadmin
  2. /var/www/html/typo3conf
  3. /var/www/html/typo3temp
  4. /var/www/html/uploads

These four directories usually store data that should be persistent. The `typo3temp/` directory is a special case; the files within it are not particularly important, but TYPO3 will read and write intensively from/to this directory. For performance reasons, it usually is a good idea to create a volume for this directory.

For storing persistent data, you can create a *data only* container, first. This container will not be running, but is only used to contain the volumes for persistent data (which is why it might be a good idea to override the container's `CMD` with `/bin/true`).

    $ docker run --name typo3-data martinhelmich/typo3:9 /bin/true

The actual application container can then be started with the `--volumes-from` flag:

    $ docker run -d \
        --name typo3-web \
        --link typo3-db:db \
        --volumes-from typo3-data \
        -p 80:80 \
      martinhelmich/typo3:9

Using this kind of setup, version updates and deployments will become easy, later. For this, simply delete the `typo3-web` container. All the important persistent data will remain safely in their volumes managed by the `typo3-data` container, and a new `typo3-web` container can be created using the same way as before:

    $ docker rm -f typo3-web
    $ docker pull martinhelmich/typo3:9
    $ docker run --name typo3-web ...

## Under the hood

The Dockerfiles used to build the images presented here can be found [on GitHub][github]. Suggestions in form of issues and pull requests are always welcome. All images are based on the [official `php` image][hub-php] (more precisely, the `php:5.6-apache` and `php:7.2-apache` image) and contain all required PHP extensions required for running TYPO3.

[hub-typo3]: https://hub.docker.com/r/martinhelmich/typo3/
[hub-php]: https://hub.docker.com/_/php/
[github]: https://github.com/martin-helmich/docker-typo3
