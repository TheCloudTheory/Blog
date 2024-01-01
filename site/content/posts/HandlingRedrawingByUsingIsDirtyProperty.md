---
title: "Handling redrawing of a component by using IsDirty property"
slug: handlingredrawingbyusingisdirtyproperty-1
summary: 'To optimize drawing operations on a Canvas element, we can implement a property, which will tell the engine whether UI is in a dirty state. Conceptually, it is quite a simple problem to solve. Technically, it involves a couple of checks, which must be process in correct order, so only dirty components are redrawn. In this post, we will discuss implementation possibilities for IsDirty property.'
date: 2023-12-31T16:12:53+01:00
type: posts
draft: false
categories:
- Javascript
tags:
- canvas
- js
- game-engine
series:
- Warp
---
When drawing anything using Canvas element, you need to decide how you're going to approach changes to the already drawn objects. The easiest solution is to always redraw everything. It's possible to optimize the process, but even if you decide, that you want the simplest route, you still to find a way to notify your engine, that there's something, which requires rendering once again. You could avoid that by just redrawing everything from scratch with each new frame, but such concept is far, far from optimal. 

## IsDirty property
As each object existing within your drawing area has some kind of state, it's actually easy to tell if it requires redrawing or not by introducing a property called `IsDirty`. In _Warp_, such property is implemented as part of `GameObject` class - a base class used by all other classes used by the engine:
```
export class GameObject {
    #id;
    #x;
    #y;

    /**
     * @description Indicates if the game object is dirty. If true, the game object will be re-rendered.
     * @date 12/28/2023 - 11:10:26 AM
     *
     * @type {boolean}
     */
    #isDirty = true;

    // Original position.
    #__x;
    #__y;

    ...
}
```
As all classes in _Warp_ derive from `GameObject` class, they can always access `IsDirty` property by using its getter:
```
get isDirty() {
    return this.#isDirty;
}
```
Accessing it is easy though. What's complicating is changing its value when really needed.

## Marking an object as dirty
Ideally, none of the object shouldn't modify `IsDirty` property value manually. If possible, its value should be set only when using a setter of any other property, which is a part of object's state. I'm saying ideally because the ideal world doesn't exist - an object could become dirty even if its state isn't directly modified. This is why `GameObject` introduces a `MarkDirty` method:
```
/**
* @description Marks the game object as dirty.
* @date 12/28/2023 - 11:10:47 AM
*
*/
markDirty() {
    this.#isDirty = true;
}
```
Unfortunately the method itself isn't enough in more complex scenarios as objects have parents, siblings and children. You need to understand how those relations affect object's state and when it really should be marked as "dirty".

## Telling a renderer to draw a new frame
In _Warp_ there's a class called `Renderer`, which is used to draw an active scene. With each frame, an instance of renderer is asked to render a new frame of the selected scene. In order to do that, renderer must understand if there's anything to draw at all.
> As we're talking mainly about rendering UI, we're making an assumption, that an instance of `Renderer` is used only for drawing user interface. In reality, _Warp_ will use the same `Renderer` to draw both UI and game objects

Renderer is unaware of existing UI components as it operates mostly on HTML level and provides access to the `Canvas` element to the rendered scene. It's a scene's responsiblity to tell a renderer, whether there's something to draw:
```
render(scene) {
    if(scene.isDirty() === false) return;
    
    this.#context.clearRect(0, 0, this.#canvas.width, this.#canvas.height);
    scene.render(this.#context);
}
```
_Warp's_ UI is a tree structure, hence by accessing the root tree object, you're able to access all the nested children. This is why `Scene` class introduces a simple implementation of a `IsDirty()` method:
```
isDirty() {
    return this.#components.some(component => component.isTreeDirty() === true);
}
```
Now comes the hard part though - we need to find a way to validate the tree to the bottom to see, if there's any dirty component. Let's discuss the `isTreeDirty()` method implementation.

## Looking for dirty components
In _Warp_ there're components, which are either self-contained objects (like `TextBlock`) or are allowed to contain children (e.g. `Container`). For the former, checking if a component is dirty is a no-brainer - we just check the `isDirty` property. Such base implementation is available in `GameObject` class like so:
```
/**
* @description Informs if the game object is dirty. If true, the game object will be re-rendered.
* @date 12/28/2023 - 4:27:41 PM
*
* @returns {boolean}
*/
isTreeDirty() {
    return this.isDirty;
}
```
For components with children we need to make sure, that we're checking the nested objects as well:
```
/**
* @description Informs if the container (including its children) is dirty. If true, the container will be re-rendered.
* @date 12/31/2023 - 2:41:29 PM
*
* @returns {*}
*/
isTreeDirty() {
    return super.isTreeDirty() || this.#children.some(child => child.isTreeDirty());
}
```
Thanks to that override, we're able to cascade down the check without a need to iterate over all the components available in the tree of objects. 

## Results
To understand the difference, let's take a look at generated reports created by profiling the engine for 30 seconds. I used the same actions for both runs:
1. Enter the scene
2. Go to second screen
3. Interact with UI
4. Go back to the first screen

Here're the results. We'll compare strict `isDirty()` checks (meaning UI is redrawn only when needed) vs redrawing UI in each frame.

### Warp performance with strict isDirty() checks
![isdirty_strict_1](/images/4_1.PNG)
![isdirty_strict_2](/images/4_2.PNG)

### Warp performance when UI is redrawn in each frame
![isdirty_loose_1](/images/4_3.PNG)
![isdirty_loose_2](/images/4_4.PNG)

### Conclusions
While the benchmarks above are far from ideal, they indicate, that redrawing UI with each frame hurts performance. Let's see:
* Scripting: 847ms (strict) vs 1024ms (**+20.9%**)
* Rendering: 124ms (strict) vs 172ms (**+38.7%**)
* Painting: 237ms (strict) vs 382ms (**+61.2%**)
* System: 594ms (strict) vs 728ms (**+22.6%**)

As for now it seems, that going for strict `isDirty()` checks moves the engine in the right direction. However, this was a benchmark using a simple UI with only a few interactive components. We'll see how it looks like once the UI gets bigger. 