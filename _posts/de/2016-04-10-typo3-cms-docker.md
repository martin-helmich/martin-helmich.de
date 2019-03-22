---
layout:     post
title:      "Gut eingepackt: TYPO3 CMS in Docker betreiben"
originalDate: 2016-04-10 21:42:28 +0200
date:       2019-03-22 17:25:28 +0100
tags:       [typo3, docker]
lang:       de
image:      /assets/headers/containers.jpg
image_license: CC BY
image_author: Glyn Lowe
image_source: https://www.flickr.com/photos/glynlowe/10039742285
disqus_id: 2d781b1b-2cca-3912-9e45-81d22325ec90
permalink: /de/blog/typo3-cms-docker.html
translations:
  de: /de/blog/typo3-cms-docker.html
  en: /en/blog/typo3-cms-docker.html
---

Für die 10. Auflage des Buchs *Praxiswissen TYPO3* (welches Ende diesen Montags im O'Reilly-Verlag erscheint), suchte ich nach einer Möglichkeit, allen Lesern einen schnellen Start mit TYPO3 zu ermöglichen - und das unter allen Betriebssystemen gleichermaßen. Die Windows-Installer, die früher in der TYPO3-Community kursierten, sind mittlerweile hoffnungslos veraltet und auch die manuelle Installation auf unixoiden Systemen war nichts für jeden.

Da ich mittlerweile sehr intensiv mit Docker arbeite und Docker über die Docker Toolbox (bzw. *Docker for Windows* und *Docker for macOS*) auch unter Windows und MacOS gut von Einsteigern benutzbar ist, beschloss ich ein entsprechendes Docker-Image zu entwickeln.

{% update Update %}
  Seit kurzem stehen auch Images für TYPO3 8.7 und 9.5 zur Verfügung. Dieser Artikel
  wurde an den entsprechenden Stellen wo nötig aktualisiert.
{% endupdate %}

## Erste Schritte

Das TYPO3-Image steht im [Docker-Hub unter dem Repository-Namen `martinhelmich/typo3`][hub-typo3] zur Verfügung. Mit untenstehendem `docker pull`-Befehl kann die jeweils aktuellste Version des Images bezogen werden:

    $ docker pull martinhelmich/typo3

Darüber hinaus kann beim Pull auch eine spezielle Version herunter geladen werden. Hierzu bietet das Repository die folgenden Tags an:

  - `martinhelmich/typo3:6` für die jeweils aktuellste 6.2 LTS-Version
  - `martinhelmich/typo3:7` für die jeweils aktuellste 7.6 LTS-Version
  - `martinhelmich/typo3:8` für die aktuellste 8.7 LTS-Version
  - `martinhelmich/typo3:9` oder `martinhelmich/typo3:latest` für die aktuellste 9.5 LTS-Version

Beachtet jedoch, dass die TYPO3-Versionen 6 und 7 bereits das Ende ihres Support-Zeitraums erreicht haben. Dies bedeutet, dass für diese Versionen keine weiteren Updates (bzw. nur noch im Rahmen des kostenpflichtigen Extended Support) veröffentlicht werden.

Das Image enthält lediglich eine PHP-FPM-Umgebung mit einem Webserver. Um die "Ein Container, eine Anwendung"-Philosophie von Docker zu befolgen, sollte für das Datenbanksystem folglich am besten ein eigener Container gestartet werden, wie hier beispielsweise ein MySQL-Container:

    $ docker run -d --name typo3-db \
        -e MYSQL_ROOT_PASSWORD=yoursupersecretpassword \
        -e MYSQL_USER=typo3 \
        -e MYSQL_PASSWORD=yourothersupersecretpassword \
        -e MYSQL_DATABASE=typo3 \
      mysql:5.7 \
        --character-set-server=utf8 \
        --collation-server=utf8_unicode_ci

{% danger Achtung %}
  Denkt daran, die Passwort-Platzhalter im obigen Code-Beispielen mit sicheren Werten zu ersetzen!
{% enddanger %}

Danach kann der eigentliche Applikationscontainer gestartet werden:

    $ docker run -d --name typo3-web \
        --link typo3-db:db \
        -p 80:80 \
      martinhelmich/typo3:9

Im Anschluss ist die laufende TYPO3-Installation unter `http://localhost` erreichbar (falls ihr die Docker Toolbox unter Windows oder MacOS nutzt, nutzt stattdessen die IP-Adresse der virtuellen Maschine, die ihr mit `docker-machine ip` herausfinden könnt).

Das im Container laufende TYPO3 ist noch nicht fertig installiert; dies bedeutet, dass ihr euch zunächst noch durch den Installationsassistenten durchklicken müsst.

## Produktiv-Deployment

Das oben beschriebene Vorgehen ist für eine Demonstration, zum Ausprobieren oder Entwickeln vollkommen ausreichend. Falls ihr das `martinhelmich/typo3`-Dockerimage im Produktivbetrieb einsetzen möchtet, sollten ein paar weitere Vorkehrungen getroffen werden.

Im Produktivbetrieb ist es besonders wichtig, sich um die Nutzdaten der TYPO3-Installation Gedanken zu machen. Das Image enthält bereits fertig vorkonfigurierte Volumes für die vier Verzeichnisse

  1. /var/www/html/fileadmin
  2. /var/www/html/typo3conf
  3. /var/www/html/typo3temp
  4. /var/www/html/uploads

Diese vier Verzeichnisse enthalten im Regelfall Nutzdaten, die nicht verloren gehen sollten. Das `typo3temp/`-Verzeichnis ist ein Sonderfall. Die Daten hierin sind zwar nicht besonders wichtig, da in diesem Verzeichnis jedoch besonders viel geschrieben und gelesen wird, ist es aus Gründen der Performance ratsam, dieses Verzeichnis als Volume zu erstellen.

Zur Haltung der Nutzdaten kann nun als erstes ein *Data-Only*-Container erstellt werden. Dieser wird später nicht laufen (daher empfiehlt es sich sogar, das CMD des Containers mit `/bin/true` zu überschreiben), sondern wird lediglich die Volumes mit Nutzdaten beinhalten:

    $ docker run --name typo3-data martinhelmich/typo3:9 /bin/true

Der eigentliche Applikationscontainer kann dann mit dem `--volumes-from`-Flag gestartet werden:

    $ docker run -d \
        --name typo3-web \
        --link typo3-db:db \
        --volumes-from typo3-data \
        -p 80:80 \
      martinhelmich/typo3:9

Auf diese Weise sind sogar später einfache Versionsupdates und Deployments möglich. Hierzu kann der `typo3-web`-Container einfach gelöscht werden; die wichtigen Nutzdaten bleiben in den Volumes des `typo3-data`-Containers erhalten und ein neuer `typo3-web`-Container kann mit denselben Daten erstellt werden:

    $ docker rm -f typo3-web
    $ docker pull martinhelmich/typo3:9
    $ docker run --name typo3-web ...

## Unter der Haube

Die Dockerfiles des hier vorgestellten Images finden sich [auf Github][github]. Anregungen in Form von Issues und Pull Requests sind stets willkommen. Alle Images basieren auf dem [offiziellen `php`-Image][hub-php] (genauer gesagt, dem `php:5.6-apache`- bzw. `php:7.2-apache`-Image) und enthalten alle notwendigen PHP-Extensions, die zum Betrieb von TYPO3 benötigt werden.

[hub-typo3]: https://hub.docker.com/r/martinhelmich/typo3/
[hub-php]: https://hub.docker.com/_/php/
[github]: https://github.com/martin-helmich/docker-typo3
