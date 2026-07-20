# Square Doom

A port of Doom for the stock Commodore 64.

This differs from my vicdoom port in that the map is a grid like Wolfenstein, but there are floor and ceiling heights and "textured" floors and ceilings to make this look much more like Doom.

It's fullscreen, using dither patterns to allow for lighting, so the pixel grid is just 40x25, which is a little rough.

The huge advantage of the tile grid is ray casting is much faster, and so is wall collision. Doors and elevators are also tile-based. Even Wolfenstein-style doors are kind of expensive. Floor heights are snapped to approximately half a meter, but the framerate is low enough that moving doors and elevators look reasonable.

I wrote an editor for this first, much like the editor I wrote for vicdoom (with the same sprites), but with height tweaking and a preview panel. Also, written in javascript instead of Adventure Game Studio.

![Editor window](editor/editor.png)

I had already experimented with squeezing the Doom levels into 32x32 tiles some time ago, so I knew that would work. Having a preview panel is super helpful for quickly matching the heights.

# Tech

The renderer is broken down into a few steps. It's not quite a pipeline. I considered making it a pipeline so I could profile it more easily, but it would have added some overhead and the later stages are hard to pipeline cleanly.

## Setup

The screen buffer is a transposed array, so columns are laid out in a linear block of memory. Each column, I take the player position and view angle and add a fisheye corrected angle to it, then make a dx and dy. Multiplies use the standard 2k table-based 8x8 multiply.

## DDA

The dx and dy are used to step through the tiles in a standard DDA approach. At each tile crossing, I determine if the tile properties have changed, and determine if the clip bounds would change. For a ledge that would narrow the clip or a crossing that changes floor or ceiling colour I need to project the crossing into screen space. I keep track of each sector entered and the clip top and bottom for each column.

## Render near

This is a floor and ceiling fill. Floors and ceilings aren't depth shaded, because I would need to calculate a depth per pixel. A span buffer and a depth per span would be possible. In the worst case would need to calculate that depth, and with the low resolution, most spans are relatively short, so it would end up pretty expensive. Instead, I just draw the floors with a dark colour, unless they are toxic sludge or the sky, which are supposed to glow.

## Render ledge

This is a step or wall fill. I use the distance traversed during the DDA to look up the dither pattern to use to fill the wall. I pick between orange and brown for the walls, similar to how Wolfenstein brightens or darkens its walls depending on whether they are east-west or north-south.

## Project Y

This converts a world space height into a screen space offset from the horizon. Normally this would be a divide, or following The Keep, a sum until the texture step (a DDA residual result) reaches the world height. The low resolution helps here because knowing that the result can only be 0..13 and the world heights are 0..31 I can use a 3k lookup table for mid to distant crossings, which are paradoxically the expensive ones.

## Items

The DDA keeps a stack of entered sectors with narrowing clip ranges, and a bit set of which sectors are visible. For each item I check if its sector is visible, then project the item onto the screen, and for each column, clip the enemy sprite. I also use mip maps for the items so that they look less noisy in the distance.

## Blit

I have a 6k fully unrolled loop to re-transpose the render to the screen and colour simultaneously.

# To do list

This is more for me than you, the reader.

## Interleave the pattern and colour blits

Currently the pattern and colour blits run in separate passes.
This results in a millisecond or so of mismatched pattern and colour.
If I interleave the blit, I can minimise the mismatch.

## Load levels from disk

Currently the level is baked into the prg.
Just need to ensure that the disk loading code doesn't stomp anything important; mostly thinking about the zeropage.
Do exactly what Willy is doing.

## Sound effects

Try porting the sound effects engine from VicDoom.
That's based on the pc speaker effects from the original game.
It's just a volume over time, IIRC.
Might need a couple more effects, for example for the elevator.

## Mips for pinky, the caco, and the baron

I have 16x32 sprites for pinky and the caco, but not for the baron.

## Music

Try recruiting @Nordischsound?
Probably still need a SID player.
At least need a budget. Maybe <1ms per frame is good enough?

## Pickups

Need the smaller pickups (health, armour, clip) and so on.

## Levels

Finish levels :)

## Editor

- Undo stack
- Don't overwrite a tile with Shift-Click. I too often do that accidentally when I want to multiselect. Instead require Shift-Alt-Click.