---
layout: post
title: Kubernetes-CRDs über die client-go-Bibliothek auslesen
date: 2018-03-28 20:00:00 +0100
tags: [kubernetes, docker, golang]
lang: de
image: /assets/headers/boat.jpg
image_license: CC-0
image_author: Pexels
image_source: https://pixabay.com/en/boat-clouds-rustic-rusty-sky-1834397
disqus_id: 3f3a070e-5770-46c1-9337-4edc91dcc927
permalink: /en/blog/kubernetes-crd-client.html
translations:
  de: /de/blog/kubernetes-crd-client.html
  en: /en/blog/kubernetes-crd-client.html
---

Der Kubernetes-API-Server kann einfach über [Custom Resource Definitions][k8s-crd] erweitert werden. Der Zugriff auf solche Ressources über die weitverbreitete [client-go][k8s-clientgo]-Bibliothek ist allerdings ein wenig komplexer und nicht sehr gründlich dokumentiert. Dieser Artikel enthält eine kurze Einführung, wie ihr auf Kubernetes-CRDs aus eurem eigenen Go-Code heraus zugreifen könnt.

[k8s-crd]: https://kubernetes.io/docs/tasks/access-kubernetes-api/extend-api-custom-resource-definitions/
[k8s-clientgo]: https://github.com/kubernetes/client-go