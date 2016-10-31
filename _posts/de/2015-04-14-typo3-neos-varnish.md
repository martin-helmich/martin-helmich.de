---
layout:     post
title:      "CMS auf Speed: TYPO3 Neos mit Varnish"
date:       2015-04-14 21:42:28 +0200
tags:       [neos, varnish]
lang: de
image:      /assets/headers/flash.jpg
image_license: CC BY
image_author: JD Hancock
image_source: https://www.flickr.com/photos/jdhancock/4698846940
disqus_id: 1bdc76e0-21b1-3c24-3512-821f485cc91c
permalink: /de/blog/typo3-neos-mit-varnish.html
translations:
  de: /de/blog/typo3-neos-mit-varnish.html
  en: /en/blog/typo3-neos-mit-varnish.html
---

Nicht, dass TYPO3 Neos im Production-Modus nicht eigentlich schon schnell genug wäre. Aus keinem anderen Grund außer "Weil ich es kann!" habe ich einmal versucht zu schauen, wie viel schneller ich diese Seite durch den Einsatz von Varnish noch machen kann. Vor allem hat mich dabei interessiert, wie gut TYPO3 Neos mit Varnish zusammenspielt.

## Überraschend einfach

Eins vorab: Ich war angenehm überrascht, wie gut sich TYPO3 Neos mit Varnish verträgt. Ich erinnere mich daran, dass ich - als ich anfing, mich mit Varnish zu beschäftigen - einmal mehrere Tage gebraucht habe, um einen Magento-Shop halbwegs vernünftig mit Varnish ans Laufen zu bekommen. Neos hingegen funktioniert mit Varnish. Einfach so. Ohne Extensions. Ohne eigenen VCL-Code. Gut, es gibt eine Extension für das Neos-Backend, die zum Beispiel automatisch den Cache leert, wenn ein Dokument bearbeitet wird. Aber das ist Luxus; das einfache Ausliefern und Cachen von Content funktioniert einfach.

Der Grund dafür ist, dass Neos (im Unterschied zu anderer Software; ja, ich meine dich, Magento!) vernünftige HTTP-Header setzt, sodass Varnish von Haus aus damit zurecht kommt. Das Wichtigste ist, dass Neos erst tatsächlich dann einen Cookie im Browser setzt, wenn auch eine Sitzung gestartet wurde.

## Vorbereitungen

{% caution Achtung %}
  Dieser Abschnitt betrifft euch nur, wenn ihr Varnish und euren Webserver (z.B. Apache, Nginx) auf demselben Server betreiben wollt.
{% endcaution %}

Falls ihr vorhabt, den Varnish-Dienst auf demselben Server zu betreiben, wie euren Webserver, solltet ihr vorher noch ein paar kleinere Anpassungen vornehmen. In der Regel sollte der Varnish-Dienst als HTTP-Proxy direkt auf Port 80 lauschen. Läuft eurer Webserver nun auf demselben Host, wird dieser wahrscheinlich ebenfalls diesen Port beanspruchen. Bevor ihr Varnish installiert, solltet ihr also euren Webserver auf einen anderen Port umbiegen.

Bei Nginx ändert ihr dazu in eurem VirtualHost (unter Debian-ähnlichen Systemen liegen die unter `/etc/nginx/sites-enabled`) folgendes:

Vorher:

```nginx
listen 80;
```

Nachher:

```nginx
listen 127.0.0.1:8080;
```

Die Änderung bewirkt einerseits, dass Nginx nun auf Port 8080 statt vorher 80 lauscht, und andererseits dass dieser Port nur noch vom lokalen Rechner erreichbar ist (das hat seine Richtigkeit; der öffentliche Traffic aus dem Internet soll ja über Varnish laufen, der dann später auf Port 80 lauschen wird).

Denkt anschließend daran, den Nginx neuzustarten:

    service nginx restart

## Varnish installieren

Ich gehe in diesem Abschnitt davon aus, dass ihr Varnish z.B. auf einem Root-Server oder für ein Docker-Image selbst installieren möchtet. Falls ihr Varnish als Managed Service einsetzt, entfällt die Installation natürlich.

Wenn ihr Ubuntu oder Debian nutzt, könnt ihr Varnish direkt aus den Paketquellen installieren. Unter Ubuntu 14.04 (und auch Debian Wheezy) bekommt ihr dabei Varnish in Version 3.0. Die ist nicht mehr ganz frisch, sollte für die meisten Fälle aber ausreichen. Für neuere Versionen gibt es auch ein [eigenes Repository vom Hersteller][varnish-ubuntu].

    $ apt-get install varnish

## Varnish konfigurieren

Die Konfigurationsdatei von Varnish ist im sogenannten VCL-Format (Varnish Configuration Language) geschrieben und liegt unter `/etc/varnish/default.vcl`. Sie enthält standardmäßig nur ein paar Kommentare, und eine Angabe, wie der eigentliche Webserver zu erreichen ist. Ich habe bei mir zusätzlich noch die `vcl_deliver`-Subroutine überschrieben (unten).

{% highlight perl linenos %}
backend default {
  .host = "127.0.0.1";
  .port = "8080";
}

sub vcl_deliver {
  if (obj.hits > 0) {
    set resp.http.X-Cache = "HIT";
  } else {
    set resp.http.X-Cache = "MISS";
  }
}
{% endhighlight %}

Die Backend-Definition sollte selbsterklärend sein; falls Varnish und der Webserver bei euch auf verschiedenen Server laufen, muss dort die IP-Adresse und der Port des Webservers eingetragen werden.

Der X-Cache-Header macht das Debugging ein wenig einfacher; anhand dieses Headers könnt ihr später sicherstellen, dass die Antworten vom Server auch tatsächlich aus dem Cache beantwortet werden.

Wenn ihr die VCL-Datei geändert habt, solltet ihr den Varnish noch einmal neustarten:

    $ service varnish start

Ab diesem Zeitpunkt sollte Varnish bereits auf Port 80 lauschen und munter eure Webseite ausliefern. Wenn ihr möchtet, könnt ihr jetzt aufhören.

## Das Backend anpassen

Aktuell bekommt der Varnish-Cache noch nichts davon mit, wenn sich am Content der Seite irgendetwas ändert. Dies bedeutet, dass der Cache gegebenenfalls immer munter weiter veralteten Content ausliefert. Diesen Zustand möchten wir nun ändern.

Für Neos gibt es das Paket *moc/varnish*, welches das Leeren des Caches übernimmt, wenn im Backend Content verändert wird. Ihr könnt es einfach über Composer installieren:

    $ composer require moc/varnish dev-master

Läuft eurer Varnish-Dienst nicht auf demselben Server wie der Webserver, müsst ihr das Paket nun noch ein wenig konfigurieren. Dies geht in der `Configuration/Settings.yaml` (unten).

{% highlight yaml linenos %}
MOC:
  Varnish:
    enableCacheBanningWhenNodePublished: true
    cacheHeaders:
      defaultSharedMaximumAge: 86400
    varnishUrl: "http://127.0.0.1/"
{% endhighlight %}

Wie ihr seht, muss das Neos-Package die Adresse des Varnish kennen, um gezielte BAN-Requests zum Leeren des Caches absetzen zu können. Per Konfiguration könnt ihr außerdem die standardmäßige Cache-Lebensdauer beeinflussen.

Zum Leeren des Caches über das Backend wird zudem noch ein wenig eigener VCL-Code benötigt:

{% highlight perl linenos %}
sub vcl_recv {
  if (req.request == "BAN") {
    if (req.http.Varnish-Ban-All) {
      ban("req.url ~ /");
      error 200 "Banned all";
    }

    if (req.http.X-Varnish-Ban-Neos-NodeIdentifier) {
      ban("obj.http.X-Neos-NodeIdentifier == " + req.http.X-Varnish-Ban-Neos-NodeIdentifier);
      error 200 "Banned TYPO3 pid " + req.http.X-Varnish-Ban-Neos-NodeIdentifier;
    }
  }
}
{% endhighlight %}

[varnish-ubuntu]: https://www.varnish-cache.org/installation/ubuntu
