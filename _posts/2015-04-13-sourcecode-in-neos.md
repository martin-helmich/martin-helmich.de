---
layout: post
title:  "Quelltext-Contentelemente für TYPO3 Neos"
date:   2015-04-13 21:42:28 +0200
categories: typo3-neos
---
Eines der Features von TYPO3 Neos, das mich am meisten begeistert, ist die Anpassungsfähigkeit des Systems. Für diese Seite brauchte ich die Möglichkeit, Quelltextbeispiele mit Syntaxhervorhebung darstellen zu können. Glücklicherweise ist so etwas in Neos überhaupt kein Problem; daher beschreibe ich heute, wie ihr in TYPO3 Neos einen eigenen NodeType hinzufügen könnt, der euch ein Content-Element mit Quelltext und Syntax-Hervorhebung in eure Neos-Seite rendert.

Ich setze an dieser Stelle voraus, dass ihr euch mit den Grundlagen von TYPO3 Neos auskennt, und insbesondere wisst

  - mit welchen Paketstrukturen Neos arbeitet und wo grob welche Dateien liegen
  - wie Inhalt in Neos strukturiert ist und dass es so etwas wie ein Content Repository gibt
  - wie ihr eigene NodeTypes erstellen könnt

## NodeTypes definieren

{% highlight yaml linenos %}
'Helmich.Homepage:SourceCode':
  superTypes:
    - 'TYPO3.Neos:Content'
  ui:
    group: general
    label: Source code
    icon: icon-code
    inspector:
      groups:
        code:
          label: Code
  properties:
    content:
      type: string
      ui:
        label: Code
        reloadIfChanged: true
        inspector:
          group: code
          position: 80
          editor: 'TYPO3.Neos/Inspector/Editors/CodeEditor'
          editorOptions:
            buttonLabel: 'Edit source code'
{% endhighlight %}

Das von Neos gewohnte Inline-Editing können wir hier leider nicht nutzen, da sich der Aloha-Editor nicht mit den <pre>-Tags verträgt, in die der Content später hineingerendert wird. Das macht aber nichts, denn genau für diesen Zweck bietet Neos bereits einen Code-Editor für den Inspektor an, der hier in Zeile 21 aktiviert wird. Auf diese Weise bekommt ihr später im Backend zur Bearbeitung des Quelltextes einen entsprechenden Editor mit Syntax-Hervorhebung bereitgestellt.

## Das Fluid-Template

Als nächstes wird nun das Fluid-Template für den NodeType definiert. Das ist keine große Raketentechnik, da wir den Quelltext ja eigentlich nur wieder so ausgeben möchten, wie er eingegeben wurde. Standardmäßig wird das Template in eurem Paket unter `Resources/Private/Templates/NodeTypes/SourceCode.html` gesucht. Das könnte man über TypoScript überschreiben; dazu besteht hier jedoch kein Anlass:

{% highlight html %}
{namespace neos=TYPO3\Neos\ViewHelpers}
{namespace media=TYPO3\Media\ViewHelpers}

<pre class="prettyprint"><code>{node.properties.content}</code></pre>
{% endhighlight %}

Das schaut ja noch recht überschaubar aus, oder? An diesem Zeitpunkt könnt ihr jetzt bereits Quelltextelemente über das Neos-Backend erstellen. Ihr habt jedoch noch keine Syntax-Hervorhebung oder den ganzen anderen Schnickschnack. Das gehen wir nun als nächstes an.

## Syntax-Highlighting konfigurieren

Für das Syntax-Highlighting nutze ich in diesem Beispiel die [Prettify-Bibliothek][prettify] von Google. Diese hat den Vorteil, dass sie rein JavaScript-seitig arbeitet, und ihr euch im PHP-Backend nicht um die Darstellung des Quelltextes zu kümmern braucht. Die Bibliothek besteht aus einigen JavaScript- und CSS-Dateien, die ihr am besten alle in das Resources/Public-Verzeichnis eures Pakets werft (bei mir liegt alles unter Resources/Public/Libraries/Prettify).

Die Bibliothek muss nun noch eingebunden werden; am einfachsten geht das im Seiten-Template:

{% highlight html linenos %}
<!DOCTYPE html>
{namespace neos=TYPO3\Neos\ViewHelpers}
{namespace ts=TYPO3\TypoScript\ViewHelpers}
{namespace tbs=TYPO3\Twitter\Bootstrap\ViewHelpers}
<html>
<head>
    <f:section name="stylesheets">
        <!-- Put your stylesheet inclusions here, they will be included in your website by TypoScript -->
    </f:section>
    <f:section name="headScripts">
        <script type="text/javascript"
                src="{f:uri.resource(path:'Libraries/Prettify/run_prettify.js', package: 'Helmich.Homepage')}?skin=desert">
        </script>
    </f:section>
</head>
<body>
    <!-- ... -->
{% endhighlight %}

## Mehr Konfigurationsmöglichkeiten

Im nächsten Schritt soll das Inhaltselement nun noch ein wenig konfigurierbarer werden. So funktioniert beispielsweise die automatische Spracherkennung von Prettify nicht besonders gut, daher wäre eine Möglichkeit sinnvoll, die gewählte Programmiersprache direkt angeben zu können. Außerdem wäre es schön, die Zeilennummerierungen ein- und ausschalten zu können.

Für beide Konfigurationen könnt ihr die ursprüngliche Definition des NodeTypes erweitern:

{% highlight yaml linenos %}
'Helmich.Homepage:SourceCode':
  superTypes:
    - 'TYPO3.Neos:Content'
  ui:
    group: general
    label: Source code
    icon: icon-code
    inspector:
      groups:
        code:
          label: Code
  properties:
    content:
      type: string
      ui:
        label: Code
        reloadIfChanged: true
        inspector:
          group: code
          position: 80
          editor: 'TYPO3.Neos/Inspector/Editors/CodeEditor'
          editorOptions:
            buttonLabel: 'Edit source code'
    lineNumbers:
      type: boolean
      defaultValue: false
      ui:
        label: 'Enable line numbering'
        reloadIfChanged: TRUE
        inspector:
          group: 'code'
          position: 60
    language:
      type: string
      defaultValue: 'auto'
      ui:
        reloadIfChanged: TRUE
        inspector:
          group: code
          position: 50
          editor: 'TYPO3.Neos/Inspector/Editors/SelectBoxEditor'
          editorOptions:
            values:
              'auto':
                label: 'Determine automatically'
              'html':
                label: 'HTML'
              'php':
                label: 'PHP'
              'xml':
                label: 'XML'
              'yaml':
                label: 'YAML'
{% endhighlight %}

Die Auswertung dieser Optionen könnt ihr am einfachen in TypoScript machen. Der Standard-Einstiegspunkt ist dabei die Datei `Root.ts2`, die standardmäßig unter `Resources/Private/TypoScript` gesucht wird:

{% highlight text linenos %}
prototype(Helmich.Homepage:SourceCode) {
  attributes.class = 'prettyprint'
  attributes.class.@process {
    language {
      expression = ${value + (q(node).property('language') != 'auto' ? ' lang-' + q(node).property('language') : '')}
    }

    lineNumbering {
      expression = ${value + (q(node).property('lineNumbers') ? ' linenums' : '')}
    }
  }
}
{% endhighlight %}

Um die in TypoScript konfigurierten Attribute nun auch im Template nutzen zu können, müsst ihr noch kurz das Fluid-Template anpassen:

{% highlight html linenos %}
{namespace neos=TYPO3\Neos\ViewHelpers}
{namespace media=TYPO3\Media\ViewHelpers}

<pre {attributes -> f:format.raw()}><code>{node.properties.content}</code></pre>
{% endhighlight %}

[prettify]: https://code.google.com/p/google-code-prettify/
