---
layout:     post
title:      "CMS on Speed: TYPO3 Neos and Varnish"
date:       2015-04-14 21:42:28 +0200
tags:       [neos, varnish]
lang: en
image:      /assets/headers/flash.jpg
image_license: CC BY
image_author: JD Hancock
image_source: https://www.flickr.com/photos/jdhancock/4698846940
disqus_id: 1bdc76e0-21b1-3c24-3512-821f485cc91c
permalink: /en/blog/typo3-neos-mit-varnish.html
translations:
  de: /de/blog/typo3-neos-mit-varnish.html
  en: /en/blog/typo3-neos-mit-varnish.html
---

Not that TYPO3 Neos would not be fast enough on its own, when you figure out how turn on the Production mode. For no other reason than "Because I can" I tried by how much I could speed up this site by using Varnish. I was particularly interested how well TYPO3 Neos and Varnish play together.

## Surprisingly easy

One thing first: I was pleasantly surprised how well TYPO3 Neos and Varnish play together. I remember - when I first had a look at Varnish - spending days trying to make a Magento Shop work at least halfway decently with Varnish. Neos, on the other hand, actually works with Varnish. Just like that. Without any extensions. Without custom VCL code. Fine, there actually is an Extension for the Neos backend that automatically flushes the cache when a document is edited. But that's just luxury; delivering and caching content simply works out-of-the-box.

The reason for that is that Neos (in contrast to other software; yes, I'm looking at you, Magento!) sets reasonable HTTP headers, enabling Varnish to work without any additional configuration. The most important part is that Neos sets a browser cookie just as soon as a session is started (and not before).

## Preparations

<div class="my-alert caution">
  <i class="glyphicon glyphicon-alert"></i>
  <div>
    <strong>Heads up!</strong> This section should concern you only when you intend to run Varnish and your web server (i.e. Apache or Nginx) on the same server.
  </div>
</div>

In case you intend to run Varnish on the same server as your web server, you should make some minor adjustments first. Usually, Varnish as a HTTP proxy should listen directly on port 80. When your web server is running on the same server, it will probably try to listen on port 80, too. So before installing Varnish, you should rewire your web server to listen at a differen port.

When using Nginx, simply edit your virtual host (in Debian-ish systems, you find those in /etc/nginx/sites-enabled) like follows:

Before:

```nginx
listen 80;
```

After:

```nginx
listen 127.0.0.1:8080;
```

On the one hand, this change causes Nginx to listen on port 8080 instead of 80. On the other hand it means that this port is reachable only from the local computer (that's actually alright; the public traffic from the internet is supposed to run through Varnish, which is going to be listening on port 80, later).

Remember to restart Nginx:

    service nginx restart

## Install Varnish

For this section, I'm assuming that you intend to install Varnish by yourself, i.e. on a root server or for a Docker image. In case you're using Varnish as a managed service, this section is moot.

When using Ubuntu or Debian, you can install Varnish directly from the package sources. In Ubuntu 14.04 (and Debian Wheezy as well) you get Varnish in version 3.0. That version has already gathered some dust, but should suffice for most use cases. For newer versions there is a [dedicated vendor repository][varnish-ubuntu].

    $ apt-get install varnish

## Configure Varnish

Varnish's configuration file is written in the VCL format (Varnish Configuration Language) and is located in `/etc/varnish/default.vcl`. By default, it contains just a few comments and a backend server definition (which is totally sufficient for a start). I've also overridden the `vcl_deliver` subroutine.

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

The backend definition should be self-explanatory: in case your Varnish and your web server are running on different hosts, you'll need to enter the web server's IP address and port.

The `X-Cache` header make debugging a bit easier; using this header you can later assert that your requests are actually answered from cache.

After changing the VCL file, you should restart Varnish:

    $ service varnish start

At this point, Varnish should already be up and running on port 80 and happily deliver you web site. If you like, you can stop now.

## Adjusting the Neos backend

Currently, the Varnish cache does not know, when the original page content changes. This means that in some cases the Cache will happily deliver stale, outdated content. That's a situation we're going to change now.

For Neos, you can use the package *moc/varnish*. It will take care of flushing the cache when content is changed in the backend. You can install it simply using Composer:

    $ composer require moc/varnish dev-master

In case your Varnish service is not running on the same server as the web server, you're going to have to configure the package a bit. You can do that in the `Configuration/Settings.yaml` file.

{% highlight yaml linenos %}
MOC:
  Varnish:
    enableCacheBanningWhenNodePublished: true
    cacheHeaders:
      defaultSharedMaximumAge: 86400
    varnishUrl: "http://127.0.0.1/"
{% endhighlight %}

As you can see, the Neos package needs to know the Varnish service's address in order to place BAN requests for cache purging. You can also modify the default cache time-to-live using the configuration file.

Finally, you'll have to add a few line of custom VCL for flushing the cache when receiving a BAN request.

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
