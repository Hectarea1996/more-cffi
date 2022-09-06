
# The more-cffi guide

## Dealing with this guide

This project extends the functionality of cffi in a very specific way. In fact, some other functionality like complex types traslation is not used. Imagine that you need to create the traslation of a complex structure and you use list or whatever. Each time you receive or use that object a traslation needs to be done and maybe you only have used one or two members. That is one of the main reasons I've created this project. Using more-cffi the user of your projects will use raw pointers almost all the time (they will not note it) and the traslations are made per-member and not per-object.

I was making this project as it goes. I think you can solve right now almost every problem that can show up when facing with C code. Despite that, I created this guide to explain how to avoid that problems at the same time I show how to use more-cffi.

Let's start!

## Dealing with documentation

The first you should know is that more-cffi can write some documentation automatically. Usually a C library has already its own documentation so you only need to tell the user how a function or a struct looks like in Common Lisp. Each macro that defines a struct or a function will gather the information you provide and write it in a formatted way. The default output format is markdown (GitHub markdow), although it can be changed.

When creating a project, it is usual to have multiple files where to write the bindings. Using more-cffi, each file would be one documentation page. That file could look like this:

```Lisp
(in-package :my-pkg)

(mcffi:with-doc-file (doc-file "path/to/file.md")

  ;; more-cffi stuff here...

  )
```

Using `with-doc-file` We specify a stream where to store the documentation. You can create your own streams using whatever you want, but more-cffi exports the `with-doc-file` macro. It is like `with-open-file` but simpler. In this example a symbol `doc-file` is bound to the file placed at `path/to/file.md`. Well, it would do that if we enable the generation. By default, the documentation generation is disabled and all the macros exported by more-cffi will only define their things without writing anything. We don't want the documentation to be generated every time the project is loaded.

When your project is ready to load, you can generate the documentation changing the value of `*doc-generation*` that defaults to `nil`. First, load more-cffi:

```Lisp
CL-USER> (asdf:load-system :more-cffi)
```

Now the symbol `*doc-generation*` is exported. Now load your project with its value set to any non-`nil` value:

```Lisp
CL-USER> (let ((mcffi:*doc-generation* t))
           (asdf:load-system :my-project :force t)) ; :force is important!
```

Make sure that all your files are processed using the `:force` option. After this, all the documentation is generated. Each time you do this, the documentation is regenerated.

## Dealing with your project structure

In this guide I will use as example a little portion of the [Common Vulkan](https://github.com/Hectarea1996/common-vulkan) project. The Vulkan library has a lot of different situations that can be problematic if we don't do the right things. The main directories of Common Vulkan are `vulkan/` and `src/`. In the former we will write the cffi bindings. And in the latter we will use more-cffi to write the wrappers and documentation.

## Dealing with cffi bindings

I won't explain how cffi works so this will be short. In the `vulkan/` directory we encounter three files:
*. `cfunctions.lisp`: Where function bindings are placed.
*. `ctypes.lisp`: Where all structs, unions, typedefs... are placed.
*. `load-vulkan.lisp`: Where the foreign library is loaded.

The third file is the first that we need to load. We need to use `define-foreign-library`. It should look like this:

```Lisp
(cffi:define-foreign-library vulkan-loader
  (:linux "libvulkan.so.1")
  (:darwin "libvulkan.1.dylib")
  (:windows "vulkan-1.dll"))

(cffi:use-foreign-library vulkan-loader)
```

Now we are ready to define the cffi bindings. As I said, in `cfunction.lisp` we can see the raw function bindings. They look like this:

```Lisp
(more-cffi:defcfun ("vkCreateInstance" vkcreateinstance
                    funcall-vkcreateinstance)
    vkresult
  (pcreateinfo :pointer)
  (pallocator :pointer)
  (pinstance :pointer))
```

Or this:

```Lisp
(more-cffi:defcfun ("vkGetPhysicalDeviceImageFormatProperties"
                    vkgetphysicaldeviceimageformatproperties
                    funcall-vkgetphysicaldeviceimageformatproperties)
    vkresult
  (physicaldevice vkphysicaldevice)
  (format vkformat)
  (type vkimagetype)
  (tiling vkimagetiling)
  (usage vkimageusageflags)
  (flags vkimagecreateflags)
  (pimageformatproperties :pointer))
```

Note that we are using here the `defcfun` symbol from the more-cffi package. We will see how to use this later. The last file in this directory is `ctypes.lisp` where are stored all the type bindings. We can see typedefs:

```Lisp
(cffi:defctype vkbool32 :uint32)
```

Structs:

```Lisp
(cffi:defcstruct vkbuffermemorybarrier
  (stype vkstructuretype)
  (pnext :pointer)
  (srcaccessmask vkaccessflags)
  (dstaccessmask vkaccessflags)
  (srcqueuefamilyindex :uint32)
  (dstqueuefamilyindex :uint32)
  (buffer vkbuffer)
  (offset vkdevicesize)
  (size vkdevicesize))
```

And unions too:

```Lisp
(cffi:defcunion vkaccelerationstructuregeometrydatakhr
  (triangles (:struct vkaccelerationstructuregeometrytrianglesdatakhr))
  (aabbs (:struct vkaccelerationstructuregeometryaabbsdatakhr))
  (instances (:struct vkaccelerationstructuregeometryinstancesdatakhr)))
```

Writing the raw bindings is the first step to create our project. Once this is done we can start creating the wrappers and documentation.

## Dealing with more-cffi

Let's begin with the interesting part. The `src/` directory contains several files. In the end each file will generate one documentation page. For example, the file `constants.lisp` contains all the constants definitions and when the documentation is generated a file `constants.md` will be created. The same occurs with the rest of the files. The most important files here are:
* `constants.lisp`
* `enums.lisp`
* `functions.lisp`
* `structs.lisp`
* `callbacks.lisp`

## Dealing with constants

First of all, we need to use `with-doc-file` to indicate where the documentation will be written:

```Lisp
(in-package :my-pkg)

(mcffi:with-doc-file (doc-file "path/to/file.md")

  ;; Constants definitions here...

  )
```

In C we can find several types of constant values. Maybe they are '#define'd:

```C
#define VK_LOD_CLAMP_NONE 1000.0F
```

Or they are defined as `const` variables:

```Lisp
;; Hypothetical example
static const uint32_t max_data_size = 512;
```

In both cases we can use the `def-foreign-constant` macro. To define the first constant `VK_LOD_CLAMP_NONE` we can do this:

```Lisp
(more-cffi:def-foreign-constant doc-file "VK_LOD_CLAMP_NONE" vk_lod_clamp_none 1000.0)
```

The first argument is the stream where the documentation will be written. The next argument is the foreign name of the constant. We can use here a string or a symbol. If a symbol is used, the foreign name will be written in lowercase. Otherwise will be used the string. The foreign name is only used for documentation and nothing more. The next argument is the name of the constant we are defining, the name users will use. And the last argument is the value of the constant. This macro expands to a `defparameter` expression. The reason `defconstant` or `cffi:defcvar` are not used is that `defparameter` is more flexible.

## Dealing with function macros

The `#define` expressions can be used also to define the so-called macro functions. Here is an example:

```Lisp
#define VK_MAKE_API_VERSION(variant, major, minor, patch) \
    ((((uint32_t)(variant)) << 29) | (((uint32_t)(major)) << 22) | (((uint32_t)(minor)) << 12) | ((uint32_t)(patch)))
```

The macro functions can be seen as a very restricted version of Lisp macros. So I will use `def-foreign-macro`:

```Lisp
(more-cffi:def-foreign-macro doc-file ("VK_MAKE_API_VERSION" vk_make_api_version) (variant major minor patch)
  `(logior (ash ,variant 29) (ash ,major 22) (ash ,minor 12) ,patch))
```

The first argument is the stream where to write the documentation. After that we specify the foreign name and lisp name of our macro. The foreign name is only used for documentation and, as in the previous example, we can use a string or a symbol. Then we specify the macro arguments and afterwards we see the body of the macro. This expands to a `defmacro` expression.

## Dealing with enumerations

To define an enumeration we can use `def-foreign-enum`. Consider this C enumeration:

```C
typedef enum VkSamplerAddressMode {
    VK_SAMPLER_ADDRESS_MODE_REPEAT = 0,
    VK_SAMPLER_ADDRESS_MODE_MIRRORED_REPEAT = 1,
    VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE = 2,
    VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_BORDER = 3,
    VK_SAMPLER_ADDRESS_MODE_MIRROR_CLAMP_TO_EDGE = 4,
    VK_SAMPLER_ADDRESS_MODE_MIRROR_CLAMP_TO_EDGE_KHR = VK_SAMPLER_ADDRESS_MODE_MIRROR_CLAMP_TO_EDGE,
    VK_SAMPLER_ADDRESS_MODE_MAX_ENUM = 0x7FFFFFFF
} VkSamplerAddressMode;
```

And this is the more-cffi version:

```Lisp
(more-cffi:def-foreign-enum doc-file "VkSamplerAddressMode"
  ("VK_SAMPLER_ADDRESS_MODE_REPEAT" 0)
  ("VK_SAMPLER_ADDRESS_MODE_MIRRORED_REPEAT" 1)
  ("VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE" 2)
  ("VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_BORDER" 3)
  ("VK_SAMPLER_ADDRESS_MODE_MIRROR_CLAMP_TO_EDGE" 4)
  ("VK_SAMPLER_ADDRESS_MODE_MIRROR_CLAMP_TO_EDGE_KHR" vk_sampler_address_mode_mirror_clamp_to_edge)
  ("VK_SAMPLER_ADDRESS_MODE_MAX_ENUM" 2147483647))
```

First we indicate the stream where to write the documentation. Then we write the type of the enum. Every enum type is defined as an `:int` type. And lastly we associate each enum member with a value. The name of the members can be a string or a symbol. Note that we can use `vk_sampler_address_mode_mirror_clamp_to_edge` right after its definition. Each member is defined using `defparameter`.

## Dealing with functions

Functions are one of the most important parts in a bindings project. The C functions can accept or return pointers so we need to make some changes in order to have a proper Lisp function. I'll show you different situations that we need to face with and I'll tell you how to deal with them.

We are going to see first the next foreign function:

```C
VKAPI_ATTR VkResult VKAPI_CALL vkCreateInstance(
    const VkInstanceCreateInfo*                 pCreateInfo,
    const VkAllocationCallbacks*                pAllocator,
    VkInstance*                                 pInstance);
```

Despite all the weird names, this a function that accepts three pointers and return a `VkResult` value. To define the raw binding we can use `defcfun` from CFFI but I'm using the one defined in more-cffi for convenience:

```Lisp
(more-cffi:defcfun ("vkCreateInstance" vkcreateinstance funcall-vkcreateinstance)
    vkresult
  (pcreateinfo :pointer)
  (pallocator :pointer)
  (pinstance :pointer))
```

This modified version of `defcfun` is almost the same as that one from CFFI. The main difference is that this version can define up to two functions. When using `cffi:defcfun` you must write the foreign name and the lisp name of the function. Here we can write two or three names. The first argument is a string of the foreign name. The second one is the lisp name of the defined function. The third one is the name of a second defined function. It is like previous one but it accept an additional first argument. It will be a pointer to the foreign function. In fact, this macro expands to `cffi:foreign-funcall` and `cffi:foreign-funcall-pointer` respectively.

The reason for defining the `funcall-` function is that sometimes we can receive a C function pointer from the call to another function. In that case the way that function is called is different. Luckily for us, the arguments are the same and so their traslations.

The Lisp wrap can be achieved using `def-foreign-function`:

```Lisp
(mcffi:def-foreign-function doc-file ("vkCreateInstance" create-instance funcall-create-instance) (pcreateinfo pallocator)
  (declare-types ("VkInstanceCreateInfo" "pCreateInfo") ("VkAllocationCallbacks" "pAllocator")
                 :return ("VkInstance" instance) ("VkResult" result))
  (let ((pallocator-c (or pallocator (cffi-sys:null-pointer))))
    (cffi:with-foreign-object (pinstance 'vkinstance)
      (let ((result (vkcreateinstance pcreateinfo pallocator-c pinstance)))
        (values (cffi:mem-ref pinstance 'vkinstance) result
                (if pallocator
                    pallocator-c
                    nil))))))
```

Let's see what is happening here. The first argument is the stream where we want the documentation to be written in. Then, same as with `defcfun`, we indicate the foreign function name and the two lisp names. Afterwards we specify the arguments. Note that the original function received three arguments while now we are receiving only two. The reason is that the third argument is a C output argument. The created `instance` will be stored in the place where the pointer is pointing to. In Lisp we should return that value together with the already returned value. But before we analyze the body look at the `declare-types` expression. In it we specify the Lisp types of the arguments and the returned values. This is used only for documentation and does not have any effect on the defined functions. Afterwards, the actual body expression begins. Since we are creating a wrapper, we need to use the original foreign function in some place. You can see it inside the `let` expression. In order to call it we need to prepare the arguments. The `pcreateinfo` and `pallocator` arguments are already pointers because they are structs (more info later). However, `pallocator` can be a `NULL` pointer and Lisp haven't that thing. We are creating the function to allow the user to pass a `nil` value. We then need to traslate it to a `NULL` pointer. So we use `cffi:null-pointer` to create a `NULL` pointer if we receive a `nil` value. The last argument needs to be created. Since we are not going to need the address of the created instance, we can create the `pinstance` argument using `with-foreign-object`. Finally we prepare the values to be returned. First we return the instance obtained by dereferencing the `pinstance` pointer. Then we return the `result` value... And, are we returning a third value? We will see why below.

When you create something in C it is 99% certain that you will need to destroy it in some moment. The above function has its `destroy` counterpart:

```C
VKAPI_ATTR void VKAPI_CALL vkDestroyInstance(
    VkInstance                                  instance,
    const VkAllocationCallbacks*                pAllocator);
```

We use `defcfun`:

```Lisp
(more-cffi:defcfun ("vkDestroyInstance" vkdestroyinstance funcall-vkdestroyinstance)
    :void
  (instance vkinstance)
  (pallocator :pointer))
```

And finally `def-foreign-function`:

```Lisp
(more-cffi:def-foreign-function doc-file ("vkDestroyInstance" destroy-instance funcall-destroy-instance) (instance pallocator)
  (declare-types ("VkInstance" instance) ("VkAllocationCallbacks" "pAllocator"))
    (let ((pallocator-c (or pallocator (cffi-sys:null-pointer))))
      (vkdestroyinstance instance pallocator-c)))
```

Here I didn't use the `:return` keyword inside `declare-type` because this function returns nothing. Like before, we need to prepare the arguments. The `pallocator` value can be `nil` and we should turn it into a `NULL` pointer. Finally we call the foreign function.

In C creating and destroying things is very common but in Lisp is not usual. For that reason more-cffi exports `defwith`. We can create `with-` macros providing only a constructor and a constructor. When using a `with-` macro we are using the constructor indirectly. In fact, we the arguments we pass to `with-` are passed directly to the constructor. But what happens with the destructor. What arguments will receive? The answer is the values that the constructor returns. Note that `destroy-instance` receives an `instance` and a `pallocator`. This values must be returned by the constructor. And that's why the constructor is returning three values!

```Lisp
(more-cffi:defwith doc-file with-instance
  create-instance
  destroy-instance
  :destructor-arguments (0 2))
```

The second argument is the name of the new `with-` macro. The third and fourth arguments are the constructor and destructor arguments. If we don't specify anything more only the first value returned by the constructor will be received by the destructor. You can specify with `:destructor-arity` the number of values passed to the destructor. Or you can use `:destructor-arguments` to specify what arguments will be passed to the destructor. In this case `destroy-instance` will receive the first and third values returned by `create-instance` (`instance` and `pallocator`). 



## Dealing with callbacks

## Dealing with structs