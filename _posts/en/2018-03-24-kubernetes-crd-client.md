---
layout: post
title: Accessing Kubernetes CRDs from the client-go package
originalDate: 2018-03-28 20:00:00 +0100
date: 2020-04-15 21:51:00 +0200
author: Martin Helmich
tags: [kubernetes, docker, golang]
lang: en
image: /assets/headers/boat.jpg
image_license: CC-0
image_author: Pexels
image_source: https://pixabay.com/en/boat-clouds-rustic-rusty-sky-1834397
disqus_id: d90027ae-f4b8-4c48-84c6-37992e420786
permalink: /en/blog/kubernetes-crd-client.html
translations:
  en: /en/blog/kubernetes-crd-client.html
---

The Kubernetes API server is easily extendable by [Custom Resource Defintions][k8s-crd]. However, actually accessing these resources from the popular [client-go][k8s-clientgo] library is a bit more complex and not thoroughly documented. This article contains a short guide on how to access Kubernetes CRDs from your own Go code (**UPDATED 2020/04** to adjust to API changes in recent `client-go` versions, using Go modules and doing (some) code generation with `controller-gen`).

## Motivation

I came across this challenge while wanting to integrate a third-party storage vendor into a Kubernetes cluster in my day job at [Mittwald](https://karriere.mittwald.de). The plan was to use Custom Resource Definitions to define things like _Filesystem Pools_ and _Filesystems_. Then, a custom Operator could listen for these resources being created and deleted and take care of the actual provisioning of these resources.

## Defining and creating a Custom Resource

For this article, we'll work with an easy example: Custom Resource Definitions can be easily created using `kubectl`, and for this example, we will start with a single simple resource definition:

{% highlight yaml linenos %}
apiVersion: "apiextensions.k8s.io/v1beta1"
kind: "CustomResourceDefinition"
metadata:
  name: "projects.example.martin-helmich.de"
spec:
  group: "example.martin-helmich.de"
  version: "v1alpha1"
  scope: "Namespaced"
  names:
    plural: "projects"
    singular: "project"
    kind: "Project"
  validation:
    openAPIV3Schema:
      required: ["spec"]
      properties:
        spec:
          required: ["replicas"]
          properties:
            replicas:
              type: "integer"
              minimum: 1
{% endhighlight %}

For defining a Custom Resource Definition, you will need to think of an _API Group Name_ (in this case, `example.martin-helmich.de`). By convention, this is usually the Domain Name of a domain that you control (for example, your organization's domain) in order to prevent naming conflicts. The CRD's name then follows the pattern `<plural-resource-name>.<api-group-name>`, so in this case `projects.example.martin-helmich.de`.

Also, be careful when choosing your definition version (`spec.version` in the example above). As long as your definitions are still evolving, it's usually a good idea to declare your first definition with an _alpha_ API group version. To users of your custom resource, this will clearly communicate that the definitions might still change, later.

Often, you want to validate the data that users store in your custom resources against a certain schema. This is what the `spec.validation.openAPIV3Schema` is for: This contains a [JSON Schema][jsonschema] that describes the format that your resources should have.

After saving the CRD in a file, you can use `kubectl` to create your resource definition:

{% highlight console %}
> kubectl apply -f projects-crd.yaml
customresourcedefinition "projects.example.martin-helmich.de" created
{% endhighlight %}

After you have created your Custom Resource Definition, you can create instances of this new resource type. These are defined like regular Kubernetes objects (like, for example, Pods, Deployments and others). Only the `kind` and `apiVersion` vary:

{% highlight yaml linenos %}
apiVersion: "example.martin-helmich.de/v1alpha1"
kind: "Project"
metadata:
  name: "example-project"
  namespace: "default"
spec:
  replicas: 1
{% endhighlight %}

You can create custom resources like any other object with `kubectl`:

{% highlight console %}
> kubectl apply -f project.yaml
project "example-project" created
{% endhighlight %}

You can even use `kubectl get` to retrieve your custom resources back from the Kubernetes API. Most other commands like `kubectl edit`, `apply` or `delete` will work, as well:

{% highlight console %}
> kubectl get projects
NAME               AGE
example-project    2m
{% endhighlight %}

## Creating a Golang client

Next, we'll use the [client-go][k8s-clientgo] package to access these custom resources. For this example, I'll assume that you are working in a Go project with the package name `github.com/martin-helmich/kubernetes-crd-example` (yes, that repository [actually exists](https://github.com/martin-helmich/kubernetes-crd-example)) and have the `client-go` and `apimachinery` libraries installed as Go modules:

    go mod init github.com/martin-helmich/kubernetes-crd-example
    go get k8s.io/client-go@v0.17.0
    go get k8s.io/apimachinery@v0.17.0

{% update Note %}
Many documentations working with CRDs will assume that you are working with some kind of code generation to generate client libraries automatically. However, this process is documented sparsely, and from reading a few heated discussions on Github, I got the impression that it's still very much a work-in-progress. We'll stick with a (mostly) manually implemented client, for now.
{% endupdate %}

### Step 1: Define types

Start by defining the types for your custom resource. I've found it to be a good practice to organize these types by the API group version; for example, you could create a file `api/types/v1alpha1/project.go` with the following contents:

{% highlight go linenos %}
package v1alpha1

import metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"

type ProjectSpec struct {
    Replicas int `json:"replicas"`
}

type Project struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

    Spec ProjectSpec `json:"spec"`
}

type ProjectList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`

	Items []Project `json:"items"`
}
{% endhighlight %}

The `metav1.ObjectMeta` type contains the typical `metadata` properties that you can find in any Kubernetes resource (like for example, the `name`, `namespace`, `labels` and `annotations`).

### Step 2: Define DeepCopy methods

Each type that is being served by the Kubernetes API (in this case, `Project` and `ProjectList`) needs to implement the `k8s.io/apimachinery/pkg/runtime.Object` interface. This interface defines the two methods `GetObjectKind()` and `DeepCopyObject()`. The first method is already provided by the embedded `metav1.TypeMeta` struct; the second you'll have to implement yourself.

The `DeepCopyObject` method is intended to generate a [deep copy](https://en.wikipedia.org/wiki/Object_copying#Deep_copy) of an object. Since this involves a lot of boilerplate code, these methods are often automatically generated. For the sake of this article, we'll do it manually. Continue by adding a second file `deepcopy.go` to the same package:

{% highlight go linenos %}
package v1alpha1

import "k8s.io/apimachinery/pkg/runtime"

// DeepCopyInto copies all properties of this object into another object of the
// same type that is provided as a pointer.
func (in *Project) DeepCopyInto(out *Project) {
    out.TypeMeta = in.TypeMeta
    out.ObjectMeta = in.ObjectMeta
    out.Spec = ProjectSpec{
        Replicas: in.Spec.Replicas,
    }
}

// DeepCopyObject returns a generically typed copy of an object
func (in *Project) DeepCopyObject() runtime.Object {
    out := Project{}
    in.DeepCopyInto(&out)

    return &out
}

// DeepCopyObject returns a generically typed copy of an object
func (in *ProjectList) DeepCopyObject() runtime.Object {
    out := ProjectList{}
    out.TypeMeta = in.TypeMeta
    out.ListMeta = in.ListMeta

    if in.Items != nil {
        out.Items = make([]Project, len(in.Items))
        for i := range in.Items {
            in.Items[i].DeepCopyInto(&out.Items[i])
        }
    }

    return &out
}
{% endhighlight %}

### Interlude: Generate the `DeepCopy` methods automatically

OK - you may have already noticed that defining all these various `DeepCopy` methods is not a lot of fun. There are many different tools and frameworks around to automatically generate these methods (all with very different levels of documentation and overall maturity). The one that I've found works best is the `controller-gen` tool, which is part of the [Kubebuilder](https://github.com/kubernetes-sigs/kubebuilder) framework:

    $ go get -u github.com/kubernetes-sigs/controller-tools/cmd/controller-gen

To use `controller-gen`, annotate your CRD types with a `+k8s:deepcopy-gen` annotation:

{% highlight go %}
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object
type Project struct {
    // ...
}

// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object
type ProjectList struct {
    // ...
}
{% endhighlight %}

Then, run `controller-gen object paths=./api/types/v1alpha1/project.go` to automatically generate the deepcopy methods.

To make things even more easy, you could add a [`go:generate` statement](https://blog.golang.org/generate) to the entire file:

{% highlight go %}
package v1alpha1

import metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"

//go:generate controller-gen object paths=$GOFILE

// ...
{% endhighlight %}

Then, just run `go generate ./...` in your root directory to update the generated code.

### Step 3: Register types at the scheme builder

Next, you'll need to make your new types known to the client library. This will allow the client to (more or less) automatically process your new types when communicating with the API server.

For this, add a new file `register.go` to your package:

{% highlight go linenos %}
package v1alpha1

import (
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/apimachinery/pkg/runtime"
    "k8s.io/apimachinery/pkg/runtime/schema"
)

const GroupName = "example.martin-helmich.de"
const GroupVersion = "v1alpha1"

var SchemeGroupVersion = schema.GroupVersion{Group: GroupName, Version: GroupVersion}

var (
    SchemeBuilder = runtime.NewSchemeBuilder(addKnownTypes)
    AddToScheme   = SchemeBuilder.AddToScheme
)

func addKnownTypes(scheme *runtime.Scheme) error {
    scheme.AddKnownTypes(SchemeGroupVersion,
        &Project{},
        &ProjectList{},
    )

    metav1.AddToGroupVersion(scheme, SchemeGroupVersion)
    return nil
}
{% endhighlight %}

As you may notice, this code does not really do anything, yet (except for creating a new `runtime.SchemeBuilder` instance).
The important part is the `AddToScheme` function (line 16), which is an exported struct member of the `runtime.SchemeBuilder` type created in line 15. You can call this function later from any part of your client code as soon as the Kubernetes client is initialized to register your type definitions.

### Step 4: Build a HTTP client

After defining types and adding a method to register them at the global scheme builder, you can now create a HTTP client that is capable of loading your custom resource.

For this, add the following code to your package's `main.go` file (for now):

{% highlight go linenos %}
package main

import (
    "flag"
    "log"
    "time"

    "k8s.io/apimachinery/pkg/runtime/schema"
    "k8s.io/apimachinery/pkg/runtime/serializer"

    "github.com/martin-helmich/kubernetes-crd-example/api/types/v1alpha1"
    "k8s.io/client-go/kubernetes/scheme"
    "k8s.io/client-go/rest"
    "k8s.io/client-go/tools/clientcmd"
)

var kubeconfig string

func init() {
    flag.StringVar(&kubeconfig, "kubeconfig", "", "path to Kubernetes config file")
    flag.Parse()
}

func main() {
    var config *rest.Config
    var err error

    if kubeconfig == "" {
        log.Printf("using in-cluster configuration")
        config, err = rest.InClusterConfig()
    } else {
        log.Printf("using configuration from '%s'", kubeconfig)
        config, err = clientcmd.BuildConfigFromFlags("", kubeconfig)
    }

    if err != nil {
        panic(err)
    }

    v1alpha1.AddToScheme(scheme.Scheme)

    crdConfig := *config
    crdConfig.ContentConfig.GroupVersion = &schema.GroupVersion{Group: v1alpha1.GroupName, Version: v1alpha1.GroupVersion}
    crdConfig.APIPath = "/apis"
    crdConfig.NegotiatedSerializer = serializer.NewCodecFactory(scheme.Scheme)
    crdConfig.UserAgent = rest.DefaultKubernetesUserAgent()

    exampleRestClient, err := rest.UnversionedRESTClientFor(&crdConfig)
    if err != nil {
        panic(err)
    }
}
{% endhighlight %}

You can now use the `exampleRestClient` created in line 48 to query all custom resources within the `example.martin-helmich.de/v1alpha1` API group. An example might look like this:

{% highlight go linenos %}
result := v1alpha1.ProjectList{}
err := exampleRestClient.
    Get().
    Resource("projects").
    Do().
    Into(&result)
{% endhighlight %}

In order to use your API in a more typesafe way, it is usually a good idea to wrap these operations within your own clientset. For this, create a new subpackage `clientset/v1alpha1`. To start, implement an interface that defines the types of your API group and move the configuration setup from your `main` method into that clientset's constructor function (`NewForConfig` in the example below):

{% highlight go linenos %}
package v1alpha1

import (
    "github.com/martin-helmich/kubernetes-crd-example/api/types/v1alpha1"
    "k8s.io/apimachinery/pkg/runtime/schema"
    "k8s.io/apimachinery/pkg/runtime/serializer"
    "k8s.io/client-go/kubernetes/scheme"
    "k8s.io/client-go/rest"
)

type ExampleV1Alpha1Interface interface {
    Projects(namespace string) ProjectInterface 
}

type ExampleV1Alpha1Client struct {
    restClient rest.Interface
}

func NewForConfig(c *rest.Config) (*ExampleV1Alpha1Client, error) {
    config := *c
    config.ContentConfig.GroupVersion = &schema.GroupVersion{Group: v1alpha1.GroupName, Version: v1alpha1.GroupVersion}
    config.APIPath = "/apis"
    config.NegotiatedSerializer = serializer.NewCodecFactory(scheme.Scheme)
    config.UserAgent = rest.DefaultKubernetesUserAgent()

    client, err := rest.RESTClientFor(&config)
    if err != nil {
        return nil, err
    }

    return &ExampleV1Alpha1Client{restClient: client}, nil
}

func (c *ExampleV1Alpha1Client) Projects(namespace string) ProjectInterface {
    return &projectClient{
        restClient: c.restClient,
        ns: namespace,
    }
}
{% endhighlight %}

The code below will not compile yet, as it's still missing the `ProjectInterface` and `projectClient` types. We'll get to those in a moment.

The `ExampleV1Alpha1Interface` and its implementation, the `ExampleV1Alpha1Client` struct are now the central point of entry for accessing your custom resources. You can now easily create a new clientset in your `main.go` by simply calling `clientset, err := v1alpha1.NewForConfig(config)`.

Next, you'll need to implement a specific clientset for accessing the `Project` custom resource (note that the example above already uses the `ProjectInterface` and `projectClient` types that we still need to supply). Create a second file `projects.go` in the same package:

{% highlight go linenos %}
package v1alpha1

import (
    "github.com/martin-helmich/kubernetes-crd-example/api/types/v1alpha1"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/apimachinery/pkg/watch"
    "k8s.io/client-go/kubernetes/scheme"
    "k8s.io/client-go/rest"
)

type ProjectInterface interface {
    List(opts metav1.ListOptions) (*v1alpha1.ProjectList, error)
    Get(name string, options metav1.GetOptions) (*v1alpha1.Project, error)
    Create(*v1alpha1.Project) (*v1alpha1.Project, error)
    Watch(opts metav1.ListOptions) (watch.Interface, error)
    // ...
}

type projectClient struct {
    restClient rest.Interface
    ns         string
}

func (c *projectClient) List(opts metav1.ListOptions) (*v1alpha1.ProjectList, error) {
    result := v1alpha1.ProjectList{}
    err := c.restClient.
        Get().
        Namespace(c.ns).
        Resource("projects").
        VersionedParams(&opts, scheme.ParameterCodec).
        Do().
        Into(&result)

    return &result, err
}

func (c *projectClient) Get(name string, opts metav1.GetOptions) (*v1alpha1.Project, error) {
    result := v1alpha1.Project{}
    err := c.restClient.
        Get().
        Namespace(c.ns).
        Resource("projects").
        Name(name).
        VersionedParams(&opts, scheme.ParameterCodec).
        Do().
        Into(&result)

    return &result, err
}

func (c *projectClient) Create(project *v1alpha1.Project) (*v1alpha1.Project, error) {
    result := v1alpha1.Project{}
    err := c.restClient.
        Post().
        Namespace(c.ns).
        Resource("projects").
        Body(project).
        Do().
        Into(&result)

    return &result, err
}

func (c *projectClient) Watch(opts metav1.ListOptions) (watch.Interface, error) {
    opts.Watch = true
    return c.restClient.
        Get().
        Namespace(c.ns).
        Resource("projects").
        VersionedParams(&opts, scheme.ParameterCodec).
        Watch()
}
{% endhighlight %}

This client is obviously not yet complete and misses methods like `Delete`, `Update` and others. However, these can be implemented similar to the already existing methods. Have a look at the existing client sets (for example, the [`Pod` client set](https://github.com/kubernetes/client-go/blob/master/kubernetes/typed/core/v1/pod.go)) for inspiration. 

After creating your client set, using it to list your existing resources becomes quite easy:

{% highlight go linenos %}
import clientV1alpha1 "github.com/martin-helmich/kubernetes-crd-example/clientset/v1alpha1"
// ...

func main() {
    // ...

    clientSet, err := clientV1alpha1.NewForConfig(config)
    if err != nil {
        panic(err)
    }

    projects, err := clientSet.Projects("default").List(metav1.ListOptions{})
    if err != nil {
        panic(err)
    }

    fmt.Printf("projects found: %+v\n", projects)
}
{% endhighlight %}

### Step 5: Build an informer

When building a Kubernetes Operator, you'll typically want to be able to react on newly created or updated resources. In theory, you could just periodically call the `List()` method and check if new resources were added. In practice, this is a sub-optimal solution, especially when you have lots of these resources.

Most operators work by initially loading all relevant instances of a resource by using an initial `List()` call, and then subscribing to updates using a `Watch()` call. The initial object list and the updates received from the watch are then used to construct a local cache that allows quick access to any custom resources without having to hit the API server every time.

This pattern is so common that the client-go library offers a helper for this: the _Informer_ from the `k8s.io/client-go/tools/cache` package. You can construct a new Informer for your custom resource as follows:

{% highlight go linenos %}
package main

import (
    "time"

    "github.com/martin-helmich/kubernetes-crd-example/api/types/v1alpha1"
    client_v1alpha1 "github.com/martin-helmich/kubernetes-crd-example/clientset/v1alpha1"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/apimachinery/pkg/runtime"
    "k8s.io/apimachinery/pkg/util/wait"
    "k8s.io/apimachinery/pkg/watch"
    "k8s.io/client-go/tools/cache"
)

func WatchResources(clientSet client_v1alpha1.ExampleV1Alpha1Interface) cache.Store {
    projectStore, projectController := cache.NewInformer(
        &cache.ListWatch{
            ListFunc: func(lo metav1.ListOptions) (result runtime.Object, err error) {
                return clientSet.Projects("some-namespace").List(lo)
            },
            WatchFunc: func(lo metav1.ListOptions) (watch.Interface, error) {
                return clientSet.Projects("some-namespace").Watch(lo)
            },
        },
        &v1alpha1.Project{},
        1*time.Minute,
        cache.ResourceEventHandlerFuncs{},
    )

    go projectController.Run(wait.NeverStop)
    return projectStore
}
{% endhighlight %}

The `NewInformer` method returns two objects: The second return value, the _controller_ controls the `List()` and `Watch()` calls and fills the first return value, the _store_ with a (more or less) recent cache of the watched resource's state on the API server (in this case, the _project_ CRD).

You can now use the _store_ to easily access your CRDs, either listing them all or accessing them by name. Keep in mind that the store functions return generic `interface{}` types, so you'll have to typecast them back to your CRD type:

{% highlight go linenos %}
store := WatchResource(clientSet)

project := store.GetByKey("some-namespace/some-project").(*v1alpha1.Project)
{% endhighlight %}

## Conclusion

Building clients for Custom Resources is something that is (at least, currently) only sparsely documented and can be a bit tricky at times.

A client library for your Custom Resource as shown in this article, along with a respective Informer is a good starting point for building your own Kubernetes operator that reacts on changes made to Custom Resources. Check the [Github project for this article][github-example] for a complete and working version.

[k8s-crd]: https://kubernetes.io/docs/tasks/access-kubernetes-api/extend-api-custom-resource-definitions/
[k8s-clientgo]: https://github.com/kubernetes/client-go
[jsonschema]: http://json-schema.org/
[github-example]: https://github.com/martin-helmich/kubernetes-crd-example
