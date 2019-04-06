---
layout: post
title: Code quality in TYPO3 projects
date: 2018-01-18 21:45:00 +0100
tags: [typo3]
lang: en
image: /assets/headers/tools.jpg
image_license: CC-0
image_author: falconp4
image_source: https://pixabay.com/en/tool-repair-work-metal-roulette-2820951/
disqus_id: 3f3a070e-5770-46c1-9337-4edc91dcc927
permalink: /en/blog/codequality-typo3.html
translations:
  de: /de/blog/codequality-typo3.html
  en: /en/blog/codequality-typo3.html
---

A while ago I wrote a [small tool for analyzing code quality in TypoScript files][github] (originally as part of a larger [article for the t3n magazine][t3n]) that since then has achieved a bit of popularity in the TYPO3 community. This article contains an updated write-up on the tool and a short guide on how to use it.

<script src="https://asciinema.org/a/1jOJv3Z6onWSdIkTAxAWsGgoy.js" id="asciicast-1jOJv3Z6onWSdIkTAxAWsGgoy" async></script>

## What is a linter?

The term "linting" dates back to the UNIX tool _lint_, which was originally intended find programming errors in C source code. By now, a "linter" is commonly understood as a tool to detect and report errors (including stylistic errors) in program source codes (source: [Wikipedia][linter]). Linters help developers to keep a consistent coding style in projects and to find potential errors as early as possible using static code analysis.

There are linters for lots of different programming languages; web developers may have stumbled upon [JSLint](http://jslint.com/), [CSSLint](http://csslint.net/) or [HTMLLint](http://htmlhint.com/). A new addition to this list is now [TypoScript Lint][github] that offers similar features for TypoScript, a language customarily used in TYPO3 projects. As a small example, let's have a look at the following TypoScript snippet:

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

There are some obvious stylistic errors in this code snipped (ordered by severity):

1. The property `page.10.templateRootPaths.10` is assigned in line 6. However, the exact same property is overwritten in line 17. This is a dangerous pitfall: an unsuspecting developer might now change line 6 in good faith, without this having any effect - an error that will cost a lot of valuable time to debug.
1. After the first assignment block to `page` has been closed, there are subsequent assignments to sub-properties of `page` in lines 15 and 17. These might be surprising, since someone reading the source code might not expect these assignments after the initial assignment block.
1. The comment in line 14 apparently contains source code that was commented out. This obstructs readability and should be removed completely. This is what version control is for!
1. Indentation is not consistent. The `10`s in lines 3 and 4 should be indented equally, but aren't. Same goes for line 7. Especially in larger files, inconsistent indentation can reduce code readability hugely.
1. The assignments to `templateRootPaths` in lines 6 and 7 start with the same path segment. For better readability, these two assignments could be grouped in a single assignment block.
1. The assignment to `layoutRootPaths` in line 9 and 10 is completely empty.

And indeed, when passed an input file with the content seen above, the TypoScript linter generates the following output, that admonished all stated errors (and even a few more):

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

A complete list of coding errors that are detected by the TypoScript linter can be found in the [project's README file][github-features].

## Installation

The TypoScript linter is installed via [Composer][composer]. Of course, this works best if the TYPO3 project in which the linter should be used is itself also managed with Composer (for setting up TYPO3 with Composer, I'll just link to the [respective README file][composer-typo3]). In this case, a simple `composer require --dev` command in the project directory is sufficient:

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

The `--dev` flag asserts that the linter is not installed when the project is deployed on a production system. After installation, the linter is available in the `vendor/bin` directory and can be called with `vendor/bin/typoscript-lint`.

If your TYPO3 project is not managed with Composer, you can use the `composer global` command to install the linter globally. In this case, the linter is available not in your project directory, but in your user's home directory; more precisely, `$HOME/.composer/vendor/bin/typoscript-lint` (if you add the `$HOME/.composer/vendor/bin` directory to your shell's search path, a simple `typoscript-lint` will be sufficient for calling the linter).

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

## Usage

After the installation, `typoscript-lint` can be called on arbitraty TypoScript files. These files will be analyzed and the linter will point out coding and style errors in the source code. The tool's output might look as follows:

![Output of `typoscript-lint`](/assets/posts/typoscript-lint-output.png)

Using the options `-f xml` and `-o outputfile.xml`, you can create an XML output file that is compatible to the popular [Checkstyle format][checkstyle]. This way, you can easily integrate the TypoScript linter in _Continuous Integration_ environments like Jenkins (for which there exists a [plugin for Checkstyle][checkstyle-jenkins]).

## Configuration

Style in programming languages is often subjective and a matter of personal taste (best example probably being the ["Tabs or Spaces?"](https://www.youtube.com/watch?v=SsoOG6ZeyUI) question). Of course, the TypoScript linter can be adjusted to these kinds of preferences. For this, a configuration file called `typoscript-lint.yml` needs to be created in your project directory (earlier versions of the liter used `tslint.yml` as file name, which lead to [obvious problems](https://palantir.github.io/tslint/)). In this file, you can for example configure the indentation (here, for using tabs for indentation instead of spaces):

{% highlight yaml linenos %}
sniffs:
  - class: Indentation
    parameters:
      useSpaces: false
      indentPerLevel: 1
{% endhighlight %}

You can also deactivate individual checks. For example, if the recommendations for nesting assignments annoy you, they can be easily disabled:

{% highlight yaml linenos %}
sniffs:
  - class: NestingConsistency
    disabled: true
{% endhighlight %}

## Questions & feedback?

The TypoScript linter is [available on GitHub][github] and licensed under the MIT license. If you should notice errors while using the linter, feel free to use the [issue tracker on GitHub][github-issues] or open up a Pull Request if you want to fix a bug or make a change to the linter by yourself.

[linter]: https://en.wikipedia.org/wiki/Lint_(software)
[composer]: https://getcomposer.org/
[composer-typo3]: https://github.com/TYPO3/TYPO3.CMS.BaseDistribution
[github]: https://github.com/martin-helmich/typo3-typoscript-lint
[github-features]: https://github.com/martin-helmich/typo3-typoscript-lint#features
[github-issues]: https://github.com/martin-helmich/typo3-typoscript-lint/issues
[t3n]: https://t3n.de/magazin/continuous-integration-typo3-236672/
[checkstyle]: http://checkstyle.sourceforge.net/
[checkstyle-jenkins]: https://wiki.jenkins.io/display/JENKINS/Checkstyle+Plugin
