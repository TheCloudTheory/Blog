---
title: "Positioning TextBlock element on a Canvas element"
summary: "Working with CanvasRenderingContext2D is quite a fun, but sometimes requires diving deeper into specification to understand more advanced concepts. In this blog post (being the very first article of a series), I'm trying to present how setting a proper value for text baseline affects positioning of drawn UI components."
date: 2023-12-30T21:29:40+01:00
type: posts
draft: false
categories:
- Programming
tags:
- canvas
- js
- text
- game-engine
- ui
series:
- Warp
---
One of the problems, which I faced recently when writing my own game engine in Javascript, is positioning a text element inside a container. As it turns out, drawing text using Canvas element seems a little bit more complicated than I anticipated and requires special care.
> Disclaimer: This post is the first part of (hopefully!) a series of articles describing a process of writing a custom game engine.

Before we dive deeper into the topic, let's introduce some context at first.

## VerticalFlow element
When building a UI for a game, you need several different basic components like containers, buttons or tabs. Lots of those components can be nested, hence they have to be aware of their parents, siblings and children. As for now, we're not going into details of positioning those components in general, but rather focus on one of available containers called **VerticalFlow**. 

The definition of a **VerticalFlow** component is pretty straighforward:
```
A vertical flow container is a container that arranges its children vertically.
```
To make a long story short - when you want to ensure, that components are positioned vertically one by another, you need to introduce a component, which will take care of automated ordering and repositioning of its children. Visually, it could look like this:
```
+-Container----------+
|                    |
|--+-VerticalFlow-+--+
|--|--+-Child1-+--|--|
|--|--+-Child2-+--|--|
|--|--+-Child3-+--|--|
|--+--------------+--|
|                    |
| +-Child4-+         |
+--------------------+
```
In such container, positioning of child component is quite tricky - you need to reposition them after obtaining all coordinates from related components and make sure, that you still have access to the original position (i.e. before repositioning). Having the original position is the implication of both drawing methods using Canvas element (most of the time you need to draw from scratch each time UI becomes "dirty"), and the fact, that component may be relative to each other. However, as long as baseline for the components stays the same, the repositioning algorithm will stay pretty simple:
```
#repositionChildren() {
    for(let i = 1; i < this.children.length; i++) {
        const child = this.children[i];
        const previousChild = this.children[i - 1];

        child.y = previousChild.y + previousChild.height;
    }
}
```
The whole repositioning operation happens of course after children are rebased using **VerticalFlow** component position. Unfortunately, the mentioned algorithm isn't sufficient when we want to draw text as one of child components.

## Problem visualized
Before introducing any modification to the algorithm, the UI containing 3 children (**TextBlock**, **TextInput**, **TextBlock**) will look like this:
![incorrectly_rendered_vertical_flow](/images/2_1.PNG)
As you can see, the first **TextBlock** element seems to be drawn correctly. That's only partially true. In fact, the spacing between the first **TextBlock** and **TextInput** shouldn't be there (for the sake of simplicity, we're considering a scenario, where none of the components has a margin). The fact, that it looks like there's a spacing, is an indicator, that the algorithm is unable to cover that scenario. Let's discuss that problem by introducing proper terminology.

## CanvasRenderingContext2D and text baseline
As you may (or may not) be aware, **CanvasRenderingContext2D** (which is the drawing context you get when referencing a Canvas element in 2D) contains a property named [textBaseline](https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/textBaseline). This property specifies the origin from which a text is drawn meaning it affects positioning of a **TextBlock** element I'm working on. When looking at the screenshot above, you may notice a **TextBlock** element with a `Map size` text rendered within **TextInput**. Even though it looks like invalid placement, it's actually correct when default value of `textBaseline` property is considered.

Let's consider the following values (based on the discussed `repositionChildren()` algorithm):
* **TextInput** (x: 0, y: 500, height: 30)
* **TextBlock** (x: 0, y: 530, height: 11)

As you can see, **TextBlock** is rendered at the bottom of **TextInput**. The reason why it ends up within **TextInput** is simple - the `y` coordinate marks the origin for `textBaseline`, so with the default value of that property, the text is drawn "upwards". Let's try to fix that.

## Setting proper baseline for text
When building a game engine, it's important to set up proper anchors, which can help us during positioning of elements. Considering available options for the `textBaseline` property, the viable options are:
* `top`
* `bottom`

Depending on our choice, the text will be render either down the origin (`top`) or up (`bottom`). The logical choice seems to be to have an anchor in top-left corner of an element, so let's go for `top`. The result of setting that value is as below:
![text_block_with_top_baseline](/images/2_2.PNG)
So far, so good! It still lacks margins, but that's something, which should be much easier to implement.

## End result
In the end, after allowing to configure spacing between children of **VerticalFlow** component, the UI looks like this:
![text_block_with_top_baseline](/images/2_3.PNG)
To achieve that, I also needed to fix obsolete rebasing of a **TextBlock** after calculating its height. This removed obsolete margin, which was visible previously as additional spacing between the first **TextBlock** and upper border of **VerticalFlow**.