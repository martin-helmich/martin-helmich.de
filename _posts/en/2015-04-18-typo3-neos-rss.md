---
layout:     post
title:      "RSS feeds with TYPO3 Neos"
date:       2015-04-15 21:42:28 +0200
tags:       [neos]
lang: en
image:      /assets/headers/newspaper.jpg
image_license: CC BY
image_author: John S.
image_source: https://www.flickr.com/photos/62693815@N03/6277209256/
disqus_id: 2fce36a4-cc12-fd3b-d805-0c8410451f89
permalink: /en/blog/rss-feeds-mit-typo3-neos.html
translations:
  de: /de/blog/rss-feeds-mit-typo3-neos.html
  en: /en/blog/rss-feeds-mit-typo3-neos.html
---

RSS (for *Really Simple Syndication*) is a XML-based format used for publishing changes of content on web sites. That's especially interesting for blog and news sites. RSS feeds can easily be imported into feed reader software, enabling visitors to be kept up-to-date. In this article, I explain how you can create an RSS feed in TYPO3 Neos.

## Configure Routing

First of all, define an alternate request format. This is done in the `Routes.yaml` configuration file - either in the global one, or in your package (which will then have to be included in the global configuration file):

{% gist martin-helmich/aab1c83379063d4beba5 Routes.yaml %}

This configuration is nearly the default config shipped by Neos, by the way. I just changed the format.

## Down into TypoScript

By default, when using a request format other than `html`, Neos will look for a TypoScript object with the same name for rendering the document. That means, when using `rss` as format, you'll need to provide a TypoScript object with the same name. I'm using the `TYPO3.TypoScript:Http.Message` class for that (which is kind of a low-level class, but perfectly suited for this). The end result is rather complex; rather than building it step by step, I'll skip ahead and just show the whole thing:

{% gist martin-helmich/aab1c83379063d4beba5 Rss.ts2 %}

And now in detail: The feed contents are rendered by a Fluid template. Some variables are assigned to this template that are derived from the current content node, resp. the current context (for example, the language). The `items` variable is a ContentCollection that is populated via an Eel expression (in my case, that's all nodes of type `Helmich.Homepage:BlogArticle`. However, that's highly individual and probably needs to be adjusted for each usecase).

Each element of this ContentCollection will be rendered using a certain section of the template. Most of the used variables are also extracted from the respective content node. The "abstract" variable will be populated with the content of the first text element contained within the respective document node.

The @cache parameter causes the output of the TypoScript object to be cached. The tag configuration means that the cache will be invalidated each time a node of type Helmich.Homepage:BlogArticle is edited (created or updated). This configuration is also usecase-dependent, though.

## The Fluid-View

Finally, the Fluid template. There's no big magic here; the template simply uses the variables that have been assigned previously in TypoScript to render a XML structure.

{% gist martin-helmich/aab1c83379063d4beba5 Rss.xml %}

## Linking the feed in your `<head>` section

Now all that's left is to annouce the feed to your visitors. Luckily, modern browsers are intelligent enough to simply read a respective meta tag than can be placed in the HTML head. That too can be done using TypoScript:

{% gist martin-helmich/aab1c83379063d4beba5 Root.ts2 %}

In this example, I've been lazy and simply specified the `${site}` node as the link target. The reason for that is that I just want a single RSS feed for the whole site anyhow (technically two, one each for German and English). But a separate feed for each page would just as easily be doable.
