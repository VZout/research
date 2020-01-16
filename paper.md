---
title: Turing Mesh Shaders
subject: Graphics Programming
category: Science
author: Viktor Zoutman (viktor@vzout.com)
link-citations: true
titlegraphic: images/pipeline.jpg
citation-style: nature.csl
abstract: In 2018 NVIDIA Released their GPU architecture, called Turing [@nvidia:ta]. Its main feature is ray-tracing [@nvidia:rtx] but Turing also introduces several other developmenhttps://www.wikihow.com/Write-an-Abstractts [@nvidia:ta-id] that look very intereresting on their own. One of these developements is the concept of *mesh shaders*. But what are mesh shaders and how can we improve use them to improve your renderear?
---

\newcommand\note[1]{\textcolor{red}{\textbf{NOTE: \emph{#1}}}}

\note{Rewrite the abstract when the paper is finished.}

\note{Figure out how to change 'lst [N]' into 'listing [N]'.}

\note{Reference api functions/intrinsics I mention within the text like `SetMeshOutputCounts`}

# Introduction

Over time the graphics pipeline has gotten more and more complicated. While some parts of the currect graphics pipeline are flexible (geometry shaders, tesselation) they are not performant and where the graphics pipeline is performant it is often not flexible (instancing).

![](images/pipeline.jpg)

Mesh shaders aim to simplyify the graphics pipeline by removing the input assembler, replacing the tesslator with a mesh generator, replacing the vertex shader and tesselation control shader with a (optional) *task shader* (Called *amplification shader* in DirectX 12). and the tesselation evaluation shader and geometry shader with a mesh shader. This simplification has the effect of introducing higher scalability and bandwidth-reduction.

\note{Explain why mesh shading is more scalable and can reduces bandwidth.}

This allows graphics programmers to satisfty the need for the high poly count and high number of objects in modern video games and graphics software like CAD.

\note{Write about subgroups and wave intrinsics in a background information or when discussing optimization of mesh shaders.}

## The Mesh Shader {#sec:themeshshader}

The mesh shader (and task shader) are basically compute shaders. A mesh shader begins its work by dispatching a set of threadgroups, each of which process a subset of the larger mesh. Similar to compute each thread has access to groupshared memory. The output vertices and primitives however do not have to corrolate to a specific thread in the group. As long as all vertices and primitives used in the threadgroup are processed, resources can be allocated in whatever way is most efficient. The user is also capable of specifying per-vertex and per-primitive attributes, which allows for faster and space efficient rendering.

There are currently 2 implementattions of mesh shaders. One in the DirectX 12 API and one as a Vulkan Extension. There are a couple of differences between these. Vulkan allows only 1 dimensional work groups. DirectX however allows for 3 dimensional work groups. DirectX also has the ability to dynamically specify the number of output vertices dynamically unlike Vulkan which only allows you to specify that value statically.

The aforementioned submeshes processed by thread groups are called *meshlets*. The idea is that the programmer algorithmicly splits the mesh in x amount of meshlets with a vertex count of 32 to around 200 vertices, depending on the number of attributes. It is most efficient to generate meshlets with as many as possible vertices that allow vertex re-use. These meshlets should be pre-computed. This is a big benefit over the old Input Assambler which has to identify vertex re-use dynamically. In [@sec:genmeshlets] I'll go over how to efficiently pre-compute meshlets.

## The Task Shader {#sec:thetaskshader}

An optional expansion in the mesh shader pipeline is the *task shader* (*amplification shader*). While the mesh shader is a flexible tool it does not allow for tessellation or efficient culling of entire meshlets.

The most basic use of a task shader is basically executing mesh shaders. We can determine for example whether a meshlet is visible and conditionally execute the mesh shader that is supposed to process the meshlet. Task shaders are capable of sharing data with its child mesh shaders and also the childs have access to the parents group shared memory. This allows you to add more triangles to the meshlet for displacement mapping for example since you can now exceed the limited vertex count per mesh shader by executing 2 mesh shaders instead.

## Executing Mesh & Task Shaders {#sec:execmeshshader}

Both Vulkan and DirectX 12 allow you to either execute mesh shaders directly or using execute indirect. Vulkan has the function `CmdDrawMeshTasksNV` with the parameters `uint32_t taskCount` and `uint32_t firstTask`. firstTask allows you to specify what mesh shader to execute first. Lets say you have a task shader and a mesh shader but they are placed in the pipeline in the order of mesh shader, task shader but you still want to execute the task shader first. In this case you can set `firstTask` to 1 and it will execute the task shader first followed my the mesh shader. The other parameter - `taskCount` - is a bit misleading. It is actually the amount of work groups in the `x` dimension you want to execute on the first task shader.

DirectX 12 is a bit more straight forward with its `DispatchMesh` function. It has the parameters `ThreadGroupCountX`, `ThreadGroupCountY` and `ThreadGroupCountZ` parameters. Each thread group size must be less than 64k and the product of $ThreadGroupCountX \times ThreadGroupCountY \times ThreadGroupCountZ$ must not exeed $2^{22}$

In Vulkan to calculate the `numTasks` parameter I use the following formula: $numTasks = (N + S - 1) / S$ where $N$ is the number of meshlets multiplied by the number of instances and $S$ is the size of the work group. DirectX is a bit more complicated since you could optimize the mesh shader in different ways using the 2 extra dimensions. For example every instance of a meshlet can be a index in the `y` dimension.

\note{Possibily explain the differences between direct and indirect execution.}

You don't need to bind a vertex buffer the traditional way anymore. Instead you are required to create a descriptor to your buffers and use that to read from the buffer directly in the mesh shader. You could just bind the vertex buffer and index buffer directly without modifying the contents of it but this is not the most efficient approach. For these optimizations see @sec:genmeshlets.

# Generating Meshlets {#sec:genmeshlets}

First of all we want to have vertices and indices we can process in the mesh shader. Remember we want to optimize the re-use of vertices so every meshlet should have the highest number of re-use possible. We can build the vertex buffer as followed:

1. Take the first triangle that hasn't already been added to a meshlet.
1. Loop over all triangles left in the mesh.
	* Find as many duplicate vertices as possible and add their parent triangle to the meshlet (without exeeding the maximum amount of vertices).
	* If there are no duplicates left add any triangle that hasn't been added to a meshlet until the maximum amount of vertices is reached.

Keep in mind that theoratically it is possible to have a vertex re-used more often than the maximum vertex count of a meshlet. Also note that you can't share a single triangle over 2 meshlets.

While you assigning vertices to meshlets you can also create the index buffer of the meshlets. We can store the indices like normal and index from the start to the end of the vertex buffer. Or you can flatten the index buffer and in the mesh shader append a "vertex start" variable to the index. This allows us to have a 32 bit index buffer where we store 4 indices in 1 value and write with one operation 4 indices to the output of the mesh shader (`writePackedPrimitiveIndices4x8NV`).

# Rendering Meshlets

> In this section I'll focus on Vulkan and mostly ignore DirectX12. Vulkan's version of wave intrinsics is called *subgroups*. You can read more about them here @vk:subgroups and see how they compare to DirectX12's wave intrinsics @dx:wi.

So first things first. We need to decide on the work group size. I found that using all the threads available in the warp (wavefront) was most efficient (32 in the case of my RTX 2060).

# Spreading Work Across Lanes

# Instancing

## Benchmarks

# Culling

## Benchmarks

# Tesselation

## Benchmarks

# Raytracing

I had hoped mesh shading would go hand in hand with ray tracing. But this doesn't seem to be the case. Of course mesh shading can still be used to accelerate hybrid raytracing but you can't reuse the meshlet buffers and descriptions in a valuable way for the acceleration structures or obtaining attributes (uv, normals and etc) in the raytracing shaders.

# Concolusion

# Further Work

There are undoubtedly many more optimization and techniques yet to be discovered. Some subjects that require research but not limited to are:

* Using wave intrinsics to share vertex and index data between instances.
* Benchmark how the `SetMeshOutputCounts`'s num vertices affects performance compared to Vulkan's approach.
* Dynamic Level of Detail approaches.
* Procedual geometry.
* Execute-Indirect and mesh shaders.
* My current approach to displacement mapping is very basic. This could undoubtedly be improved drastically.

# Change-log

## 01 - 15 - 2020

* Added notes
* Fixed spellings errors
* Rewrote [@sec:themeshshader]
* Rewrote [@sec:execmeshshader]
* Wrote [@sec:thetaskshader]
* Wrote [@sec:genmeshlets]

# References
