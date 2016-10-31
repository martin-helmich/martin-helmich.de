---
layout:        post
title:         Source code content elements for TYPO3 Neos
date:          2015-04-13 21:42:28 +0200
tags:          [neos]
lang:          en
image:         /assets/headers/neos-sourcecode.jpg
image_license: CC BY-SA
image_author:  Martin Helmich
disqus_id:     0b5a5243-9c0e-b5dd-c9ce-80da73c3f781
permalink:     /en/blog/source-code-content-in-neos.html
translations:
  de: /de/blog/quelltext-content-in-neos.html
  en: /en/blog/source-code-content-in-neos.html
---
Of all the features of TYPO3 Neos, one that astonishes me most is the system's extensibility. For this site, I needed the possibility to present source code examples with syntax highlighting. Luckily, that isn't any problem at all in Neos. In this article, I describe how you can extend TYPO3 Neos with a custom NodeType that renders a content element with source code and syntax highlighting into your Neos site.

At this point I'm assuming that you know about the TYPO3 Neos basics, and especially know

  - how the Neos package structures looks like and which files are stored where
  - how content is structured in Neos and that there's something like a Content Repository
  - how to create your own Node Types

## Define Node Types

Start by defining the corresponding node type. This is done in the configuration file `Configuration/NodeTypes.yaml` in your own site package. For my example, I'm using the package key `Helmich.Homepage`. When taking over code examples, remember to adjust the package key according to your own needs:

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

Unfortunately, we cannot use the inline editing that we already know from Neos. This is because the Aloha editor does not get along with the `<pre>` tags that the content will be rendered into later. That's not a big thing, though, because Neos offers a special code editor just for this case. This editor is activated in the snippet above in line 21. Using this editor, Neos will offer you a fully functional source code editor with syntax highlighting in the backend for editing the source code content.

## The Fluid Template

Next, define the Fluid template for the Node Type. This isn't overly complex, because after all, we simply want to output the source code exactly the same way that it was entered. By default, Neos will look for the template in `Resources/Private/Templates/NodeTypes/SourceCode.html`. You could override this convention using TypoScript, but why should you?

{% highlight html %}
{namespace neos=TYPO3\Neos\ViewHelpers}
{namespace media=TYPO3\Media\ViewHelpers}

<pre class="prettyprint"><code>{node.properties.content}</code></pre>
{% endhighlight %}

That's not too hard, is it? At this point, you can already create source code content elements in the Neos backend. You don't have syntax highlighting or any other fancy stuff yet, though. That's what's next.

## Configure syntax highlighting

For syntax highlighting, I'm using [Google's Prettify library][prettify]. It's working entirely in JavaScript, which saves you the trouble of processing the source code in your PHP backend. The library consists of some JavaScript and CSS files, which you best put into the `Resources/Public` directory of your package (I'm using `Resources/Public/Libraries/Prettify` for that).

Now all that's left is to include the library. The easiest way to do that is using the page template:

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

## More configuration!

In the last step I'd like to make the content element a bit more configurable. For example, Prettify's automatical language recognition does not work that well at times, and it would be nice to specify the used programming language in the Neos backend. Another nice feature would be to enable or disable the line numbering in the source code examples.

For both configuration options, you can extend the original node type definition:

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

Evaluating these options is best done in TypoScript. The standard point of entry is the file `Root.ts2`, which Neos will look for in `Resources/Private/TypoScript`:

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

In order to use the attributes configured in TypoScript in your template, you'll need to adjust the Fluid template:

{% highlight html linenos %}
{namespace neos=TYPO3\Neos\ViewHelpers}
{namespace media=TYPO3\Media\ViewHelpers}

<pre {attributes -> f:format.raw()}><code>{node.properties.content}</code></pre>
{% endhighlight %}

[prettify]: https://code.google.com/p/google-code-prettify/
