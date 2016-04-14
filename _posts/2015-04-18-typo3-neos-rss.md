---
layout:     post
title:      "RSS-Feeds mit TYPO3 Neos"
date:       2015-04-15 21:42:28 +0200
tags:       [TYPO3 Neos]
image:      /assets/headers/newspaper.jpg
image_license: CC BY
image_author: John S.
image_source: https://www.flickr.com/photos/62693815@N03/6277209256/
---

RSS (für *Really Simple Syndication*) ist ein XML-basiertes Dateiformat, über das Veränderungen an Websites bekannt gemacht werden können. Speziell für Blog- und Nachrichtenseiten bieten sich solche RSS-Feeds an; Leser können diesen einfach in einen Feed-Reader einbinden, um auf dem Laufenden zu bleiben. In diesem Artikel erkläre ich euch, wie ihr in TYPO3 Neos solch einen Feed erstellen könnt.

## Routing konfigurieren

Zunächst definieren wir ein alternatives Request-Format. Dies geschieht in der Datei Routes.yaml (entweder einfach in der globalen, oder in eurem Package, welches dann aber explizit in der globalen Datei eingebunden werden muss):

{% gist martin-helmich/aab1c83379063d4beba5 Routes.yaml %}

Diese Konfiguration entspricht übrigens nahezu der Standard-Konfiguration, die Neos für das Ausliefern von Content mitliefert. Lediglich das Format ist geändert.

## Ab ins TypoScript

Ab ins TypoScript
Die Standard-TypoScript-Konfiguration von Neos sieht bereits vor, dass bei einem Format, das anders lautet als `html` einfach das TypoScript-Objekt mit dem entsprechenden Namen gerendert wird. Wir müssen an dieser Stelle also nur noch das Objekt mit dem Namen `rss` implementieren. Da hier z.B. auch HTTP-Header verändert werden müssen (wir haben ja schließlich einen anderen Content-Type), kann hier am besten gleich die `TYPO3.TypoScript:Http.Message`-Klasse genutzt werden. Das Endergebnis ist recht komplex; anstatt es nach und nach aufzubauen, präsentiere ich erstmal den ganzen Block:

{% gist martin-helmich/aab1c83379063d4beba5 Rss.ts2 %}

Nun im Detail: Der Inhalt des Feeds wird von einem Fluid-Template gerendert. Dem Template werden einige Variablen zugewiesen, die aus der aktuellen Content Node, bzw. dem Kontext geladen werden (z.B. die Sprache). Die Variable `items` ist schließlich eine ContentCollection, die in diesem Fall von einer Eel-Expression befüllt wird (hier sind das alle Nodes vom Typ `Helmich.Homepage:BlogArticle`; das ist aber hochindividuell und muss je nach Usecase angepasst werden).

Jedes Element dieser ContentCollection wird dann mit einem bestimmten Abschnitt des Templates gerendert. Die meisten Variablen werden auch hier aus der jeweiligen Node bezogen. Als `abstract`-Variable wird der Inhalt des ersten Text-Elements unterhalb der jeweiligen Node ausgewählt.

Der `@cache`-Parameter definiert schließlich, dass die Ausgabe gecached werden soll. Die Tag-Konfiguration bewirkt, dass der Cache jedes Mal invalidiert wird, wenn eine Node vom Typ `Helmich.Homepage:BlogArticle` bearbeitet wird. Aber auch diese Konfiguration muss wahrscheinlich individuell angepasst werden.

## Der Fluid-View

Abschließend noch das Fluid-Template. Dieses ist recht unspannend, da lediglich die Variablen, die zuvor im TypoScript zugewiesen wurden, in eine XML-Struktur regendert werden.

{% gist martin-helmich/aab1c83379063d4beba5 Rss.xml %}

## Verlinkung im `<head>`-Bereich

Nun müssen die Besucher der Seite nur noch darauf aufmerksam gemacht werden, dass es den RSS-Feed gibt. Glücklicherweise sind moderne Browser intelligent genug, und lesen einfach einen meta-Tag aus, der im HTML-Head platziert werden kann. Auch das können wir über TypoScript machen:

{% gist martin-helmich/aab1c83379063d4beba5 Root.ts2 %}

Ich habe es mir in diesem Beispiel einfach gemacht, und als Ziel-Node des Links die `${site}`-Node angegeben. Der Grund dafür ist, dass ich nur einen RSS-Feed für die ganze Seite haben möchte (technisch gesehen zwei, je einmal auf Deutsch und Englisch). Aber auch ein eigener Feed pro Seite ließe sich auf diese Weise einfach umsetzen.
