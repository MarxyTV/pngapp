# PngApp made with LÖVE

Reactive PNG application made with Love2D game engine.

Currently it supports 5 animation frames.
- Eyes Open/Closed with Mouth Open/Closed
- Scream (for when mic peaks)


## Talking/Scream threshold

The volume thresholds for talking and scream are adjustable.
You can also set the talk decay. This is how long to wait after talking before resetting to the mouth closed state.


## Shake

The shake function picks a random x,y position scaled by the mic volume * shake scale.
The scream shake has a seperate scale multiplyer.

Lerp Speed is the speed at which the image returns back to its origin.
Shake Type is the easing function used to return image to origin.
Shake delay is how soon after triggering a shake jump, another can be triggered.

## Blink

There are settings to adjust the chance, duration, and after blink delay.

## Background Color

NOTE: If you would like to avoid chroma key in OBS, set "Allow Transparency" in OBS source settings, and set background color to black in the pngapp settings. This is how I personally use it to stream.

You can adjust the background color to make it easier to see while adjusting options and for chroma key-ing in applications like OBS.

## Moving

You can hold right click to drag the image around and use scroll wheel to zoom in/out.

## Save/Load

You can save your settings, revert to defaults, and revert to last loaded/saved settings.


## Server

windows command

`cmd -C echo {"name":"changeSlot","args":{"slot":1}} | ncat -C localhost 20501`

linux command (bash script)

`echo {"name":"changeSlot","args":{"slot":1}} | netcat localhost 20501`

available commands:

- sleepToggle (ex: `{"name":"sleepToggle"}`)
- changeSlot (ex: `{"name":"changeSlot","args":{"slot":1}}`)