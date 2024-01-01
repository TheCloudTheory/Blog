---
title: "Buttons, event handlers and PropertyChanged notifications"
slug: buttonseventhandlersandpropertychangednotification
summary: 'When working on UI in a game engine, one of the challenges is to handle changes to a state of a component. Doing that in proper way is crucial to decouple components and allow yourself to define the whole UI with minimal overhead and quirks. In this blog post, we will discuss how Warp is able to render a few buttons, which can interact with each other.'
date: 2024-01-01T16:35:11+01:00
type: posts
draft: false
categories:
- Programming
tags:
- canvas
- js
- game-engine
- ui
series:
- Warp
---
Just recently I added `HorizontalFlow` component to _Warp_, which allows you to render child components horizontally:
![horizontal_flow](/images/5_1.PNG)
As you can see above, I have three buttons, which are all part of the same container. Instead of positioning them manually, I used a dedicated container, which takes of positioning automatically. Conceptually, `HorizontalFlow` works in the same way as `VerticalFlow`. The only difference is logic responsible for repositioning children it contains.

Once I added buttons, I wanted to implement one more thing - once a player clicks on a button, the button must stay in _hovered_ state. Let's check the current implementation.

## Adding `isActive` property
UI components should be allowed to indicate, that they're _active_. However, being _active_ may have different meaning for different components. This is a problem - under normal circumstancies I'd say, that each component is supposed to override setter of `isActive` property. As _Warp_ is written in vanilla JS, which has rather limited OOP capabilities (meaning - you can achieve almost everything, but some solutions are clumsy as hell), I started thinking about something more robust. This is when an idea of `__notifyPropChanged` was born.

## Notify when property changes
_Warp's_ base class `GameObject` introduced a boilerplate `__notifyPropChanged` method acting as a default implementation so we can avoid errors:
```
/**
* @description Allow to register a hook to be called when a property changes.
* @date 12/31/2023 - 2:16:14 PM
*
* @param {*} property
* @param {*} oldValue
* @param {*} newValue
*/
__notifyPropChanged(property, oldValue, newValue) {
    return;
}
```
This immediately enables us to use that method in some real case scenarios. For instance, _Warp_ currently has a convention, which introduces publishing mechanism in each setter defined in any of available classes. Here's example of setters for `x` and `y` properties, which are defined inside `GameObject`:
```
set x(value) {
    this.__notifyPropChanged('x', this.#x, value);
    this.#x = value;
    this.markDirty();
}

set y(value) {
    this.__notifyPropChanged('y', this.#y, value);
    this.#y = value;
    this.markDirty();
}
```
The same convention is used by `UIObject`, where `isActive` property is defined:
```
set isActive(value) {
    this.__notifyPropChanged('isActive', this.#isActive, value);
    this.#isActive = value;
    this.markDirty();
}
```
To wrap up implementation, I added `__notifyPropChanged` override in `Button` class:
```
__notifyPropChanged(property, oldValue, newValue) {
    super.__notifyPropChanged(property, oldValue, newValue);

    if (property === 'isActive' && newValue === false) {
        this.fillColor = this.__fillColor;
    }
}
```
This allows us to reset button's color each time it's set as not active. Let's see now how one can use those new concepts when describing a scene.

## Allowing buttons to reset each other's state
An example of a button component definition could look like this:
```
const newGameMapSizeSmallButton = new Button('main-menu-new-game-map-size-small-button', { 
    x: 0,
    y: 0,
    width: 50,
    height: 30,
    anchor: UI_OBJECT_ANCHOR_MIDDLE_CENTER,
    parent: newGameMapSizeSelectionHorizontalFlow,
    fillColor: COLOR_PRIMARY_BACKGROUND,
    borderColor: COLOR_OUTLINE,
    text: 'Small',
    textColor: COLOR_OUTLINE,
    fillColorHighlight: COLOR_HIGHLIGHT,
    eventHandlers: {
        onClick: (component) => {
            component.isActive = true;
            newGameMapSizeMediumButton.isActive = false;
            newGameMapSizeLargeButton.isActive = false;
        }
    }
});
```
As you can see, there's `onClick()` event handler, which performs three actions:
* sets a button as _active_
* sets the second button as _not active_
* sets the third button as _not active_

The result will be as follows:
![active_button_showcase](/images/5_2.gif)
There's still one thing missing here (resetting a state of a button once a player clicks outside of buttons inside `HorizontalFlow`), but that a matter of adding one more event handler to the root container of UI.