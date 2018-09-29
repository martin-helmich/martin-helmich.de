---
layout: post
title: Codequalität in TYPO3-Projekten
date: 2018-01-18 21:45:00 +0100
tags: [typo3]
lang: de
image: /assets/headers/tools.jpg
image_license: CC-0
image_author: falconp4
image_source: https://pixabay.com/en/tool-repair-work-metal-roulette-2820951/
disqus_id: 3f3a070e-5770-46c1-9337-4edc91dcc927
permalink: /de/blog/codequality-typo3.html
translations:
  de: /de/blog/codequality-typo3.html
  en: /en/blog/codequality-typo3.html
---

Vor einiger Zeit schrieb ich (ursprünglich als Teil eines größeren [Artikels für das t3n-Magazin][t3n]) ein [kleines Tool zur Analyse der Codequalität in TypoScript-Dateien][github], welches sich auch nach einigen Jahren noch einer gewissen Beliebtheit erfreut. Aus diesem Grund gibt es hier noch einmal eine kurze Zusammenfassung und einen Überblick über die Benutzung.

<script src="https://asciinema.org/a/1jOJv3Z6onWSdIkTAxAWsGgoy.js" id="asciicast-1jOJv3Z6onWSdIkTAxAWsGgoy" async></script>

## Was ist ein Linter?

Der Begriff des "Lintings" geht auf das betagte Unix-Tool _lint_ zurück. Dieses diente ursprünglich dazu, Programmierfehler in C-Quelltexten zu finden. Mittlerweile versteht man unter einem "Linter" ein Tool, das Fehler (einschließlich stilistischer Fehler) in Programmquelltexten erkennt und meldet (Quelle: [Wikipedia][linter]). Linter helfen Entwicklern, in Projekten einen einheitlichen Programmierstil einzuhalten, und mögliche Fehler möglichst früh durch statische Codeanalyse zu erkennen.

Linter gibt es für alle möglichen Programmiersprachen; Web-Entwickler kennen womöglich [JSLint](http://jslint.com/), [CSSLint](http://csslint.net/) oder [HTMLLint](http://htmlhint.com/). In diese Liste reiht sich nun auch [TypoScript Lint][github] ein, welches ähnliche Funktionen für das in TYPO3-Projekten gebräuchliche TypoScript anbietet. Als kleines Beispiel sei folgender TypoScript-Quelltext betrachtet:

{% highlight typoscript linenos %}
page = PAGE
page  {
  10 = FLUIDTEMPLATE
   10 {
    templateName = Default
    templateRootPaths.10 = fileadmin/templates
   templateRootPaths.20 = EXT:mysite/Resources/Private/Templates

    layoutRootPaths {
    }
  }
}

#page.includeJS.main = fileadmin/js/app.js
page.includeJS.main = fileadmin/js/app.min.js

page.10.templateRootPaths.10 = fileadmin/templates2
{% endhighlight %}

In diesem Code-Abschnitt gibt es einige offensichtliche stilistische Punkte zu bemängeln (sortiert nach Schwere):

1. In Zeile 6 wird die Eigenschaft `page.10.templateRootPaths.10` zugewiesen. Allerdings wird genau diese Eigenschaft in Zeile 17 wieder überschrieben. Dies ist eine gefährliche Falle: Ein unbedachter Entwickler könnte nun im guten Glauben Zeile 6 verändern, ohne dass dies irgendeine Auswirkung hätte -- ein Fehler, den zu debuggen dann im Anschluss wertvolle Zeit kosten würde.
1. Nachdem der erste Zuweisungsblock zu `page` geschlossen wurde, folgt noch eine zweite Zuweisung zu einem Unterobjekt von `page`. Dies könnte überraschen, da ein Leser des Quelltextes nicht unbedingt damit rechnet, dass nach dem Zuweisungsblock noch einzelne Unterattribute des `page`-Objekts zugewiesen werden.
1. Die Kommentarzeile in Zeile 14 enthält offensichtlich auskommentierten Code. Dieser stört die Lesbarkeit und sollte komplett entfernt werden. Dafür gibt es ja schließlich Versionsverwaltung!
1. Die Einrückung der Datei ist nicht konsistent. Die `10` in den Zeilen 3 und 4 sollten gleich weit eingerückt sein, sind es aber nicht. Gleiches gilt in Zeile 7. Gerade in größeren Dateien können solche Einrückungsfehler der Lesbarkeit des Quelltextes enorm schaden.
1. Die Zuweisungen zu `templateRootPaths` in den Zeilen 6 und 7 beginnen mit demselben Pfad-Segment. Zur besseren Lesbarkeit könnten diese beiden Zuweisungen in einen Block ausgelagert werden.
1. Die Zuweisung zu `layoutRootPaths` ist komplett leer.

Und tatsächlich generiert der TypoScript-Linter bei einer Eingabedatei mit obigem Inhalt folgende Ausgabe, welche alle oben angemerkten Fehler (und sogar noch ein paar mehr) ankreidet:

```txt
Completed with 8 issues

CHECKSTYLE REPORT
=> /Users/mhelmich/Git/Github/typo3-ci-example/test.typoscript.
   2 Accessor should be followed by single space.
   4 Expected indent of 2 spaces.
   6 Value of object "page.10.templateRootPaths.10" is overwritten in line 17.
   6 Common path prefix "templateRootPaths" with assignment to "templateRootPaths.20" in line 7. Consider merging them into a nested assignment.
   7 Expected indent of 4 spaces.
   7 Common path prefix "templateRootPaths" with assignment to "templateRootPaths.10" in line 6. Consider merging them into a nested assignment.
   9 Empty assignment block
  14 Found commented code (page.includeJS.main = fileadmin/js/app.js).
  15 Assignment to value "page.includeJS.main", altough nested statement for path "page" exists at line 2.
  17 Assignment to value "page.10.templateRootPaths.10", altough nested statement for path "page" exists at line 2.
  17 Common path prefix "page" with assignment to "page.includeJS.main" in line 15. Consider merging them into a nested assignment.

SUMMARY
12 issues in total. (11 warnings, 1 infos)
```

Eine vollständige Liste aller vom TypoScript-Linter erkannten Fehler findet sich in der [README des Projekts][github-features].

## Installation

Der Typoscript-Linter wird per [Composer][composer] installiert. Das funktioniert natürlich am besten, wenn das TYPO3-Projekt, in dem der Linter genutzt werden soll, selbst ebenfalls mit Composer verwaltet wird (zum Setup von TYPO3 mit Composer sei auf die [zugehörige README verwiesen][composer-typo3]). In diesem Fall reicht ein einfaches `composer require --dev` im Projektverzeichnis:

{% highlight console %}
> composer require --dev helmich/typo3-typoscript-lint
Using version ^1.4 for helmich/typo3-typoscript-lint
./composer.json has been updated
Loading composer repositories with package information
Updating dependencies (including require-dev)
Package operations: 7 installs, 0 updates, 0 removals
  - Installing symfony/filesystem (v4.0.3): Downloading (100%)
  - Installing symfony/config (v4.0.3): Downloading (100%)
  - Installing psr/container (1.0.0): Downloading (100%)
  - Installing symfony/dependency-injection (v4.0.3): Downloading (100%)
  - Installing helmich/typo3-typoscript-parser (v1.1.2): Downloading (100%)
  - Installing symfony/event-dispatcher (v4.0.3): Downloading (100%)
  - Installing helmich/typo3-typoscript-lint (v1.4.4): Downloading (100%)
Writing lock file
Generating autoload files
Generating  class alias map file
Inserting class alias loader into main autoload.php file
{% endhighlight %}

Das `--dev`-Flag stellt sicher, dass der Linter nicht mit installiert wird, wenn das Projekt auf einem Produktivsystem installiert wird. Der Linter steht im Anschluss im Verzeichnis `vendor/bin` zur Verfügung und kann mit `vendor/bin/typoscript-lint` aufgerufen werden.

Falls euer TYPO3-Projekt nicht mit Composer verwaltet wird, kann auch der `composer global`-Befehl genutzt werden, um den Linter global zu installieren. In diesem Fall steht der Linter dann nicht im Projektverzeichnis, sondern im Home-Verzeichnis eures Nutzers unter `$HOME/.composer/vendor/bin/typoscript-lint` zur Verfügung (wenn ihr das Verzeichnis `$HOME/.composer/vendor/bin` in euren Suchpfad eintragt, reicht anschließend auch ein einfaches `typoscript-lint` zum Aufruf).

{% highlight console %}
> composer global require helmich/typo3-typoscript-lint
Changed current directory to /Users/mhelmich/.composer
Using version ^1.4 for helmich/typo3-typoscript-lint
./composer.json has been created
Loading composer repositories with package information
Updating dependencies (including require-dev)
Package operations: 11 installs, 0 updates, 0 removals
  - Installing symfony/yaml (v4.0.3): Loading from cache
  - Installing symfony/filesystem (v4.0.3): Loading from cache
  - Installing symfony/config (v4.0.3): Loading from cache
  - Installing psr/container (1.0.0): Loading from cache
  - Installing symfony/dependency-injection (v4.0.3): Loading from cache
  - Installing helmich/typo3-typoscript-parser (v1.1.2): Loading from cache
  - Installing symfony/event-dispatcher (v4.0.3): Loading from cache
  - Installing symfony/finder (v4.0.3): Loading from cache
  - Installing symfony/polyfill-mbstring (v1.6.0): Loading from cache
  - Installing symfony/console (v4.0.3): Loading from cache
  - Installing helmich/typo3-typoscript-lint (v1.4.4): Loading from cache
Writing lock file
Generating autoload files
{% endhighlight %}

## Nutzung

Nach der Installation kann `typoscript-lint` auf beliebige Typoscript-Dateien aufgerufen werden. Die Dateien werden analyisiert, und das Tool wird euch auf Stilfehler (und auch echte Fehler) im Quelltext hinweisen. Die Ausgabe des Tools könnte beispielsweise aussehen wie folgt:

![Ausgabe von `typoscript-lint`](/assets/posts/typoscript-lint-output.png)

Mit den Optionen `-f xml` und `-o ausgabedatei.xml` kann auch eine XML-Ausgabedatei generiert werden, die dem verbreiteten [Checkstyle-Format][checkstyle] folgt. Auf diese Weise kann der Typoscript-Linter bequem in _Continuous Integration_-Umgebungen wie etwa Jenkins integriert werden (für das ein [Plugin für Checkstyle][checkstyle-jenkins] existiert).

## Konfiguration

Stilfragen in Programmiersprachen ist häufig subjektiv und abhängig von persönlichen Vorlieben. Bestes Beispiel ist wahrscheinlich die ["Tabs oder Spaces?"](https://www.youtube.com/watch?v=SsoOG6ZeyUI)-Frage. Natürlich kann der TypoScript-Linter an derartige Präferenzen angepasst werden. Hierzu muss im Projektverzeichnis eine Konfigurationsdatei `tslint.yml` hinterlegt werden. Hier kann beispielsweise die Einrückung konfiguriert werden (hier etwa für die Einrückung mit Tabs statt Spaces):

{% highlight yaml linenos %}
sniffs:
  - class: Indentation
    parameters:
      useSpaces: false
      indentPerLevel: 1
{% endhighlight %}

Auch das Deaktivieren einzelner Überprüfungen ist möglich. Wenn euch beispielsweise die Empfehlungen für das Verschachteln von Statements nerven, kann diese Überprüfung einfach deaktiviert werden:

{% highlight yaml linenos %}
sniffs:
  - class: NestingConsistency
    disabled: true
{% endhighlight %}

## Fragen & Feedback?

Der TypoScript-Linter ist [auf GitHub verfügbar][github] und steht unter der MIT-Lizenz zur Verfügung. Fällt euch bei der Nutzung des Linters ein Fehler auf, nutzt gerne den [Bugtracker auf GitHub][github-issues]. Auch Verbesserungsvorschläge in Form von Pull Requests sind stets willkommen.

[linter]: https://en.wikipedia.org/wiki/Lint_(software)
[composer]: https://getcomposer.org/
[composer-typo3]: https://github.com/TYPO3/TYPO3.CMS.BaseDistribution
[github]: https://github.com/martin-helmich/typo3-typoscript-lint
[github-features]: https://github.com/martin-helmich/typo3-typoscript-lint#features
[github-issues]: https://github.com/martin-helmich/typo3-typoscript-lint/issues
[t3n]: https://t3n.de/magazin/continuous-integration-typo3-236672/
[checkstyle]: http://checkstyle.sourceforge.net/
[checkstyle-jenkins]: https://wiki.jenkins.io/display/JENKINS/Checkstyle+Plugin