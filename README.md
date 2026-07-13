# Square Doom

A port of Doom for 6502 machines (not sure which yet - VIC-20 or C64 or BBC master perhaps).

This will differ from my vicdoom port in that the map will be a grid like Wolfenstein, but there
will be floor and ceiling heights to make this look much more like Doom.

I'm also undecided on the texture mapping. Possibly I'll just go with flat colours for a speed bump
and so that it fits in a smaller memory footprint.

The huge advantage of the tile grid is ray casting is much faster, and so is wall collision.
Some things may look a little off though, such as doors, which will be super chunky, and moving floors
which will be snapped to approximately half a meter.

Starting with an editor, much like the editor I wrote for vicdoom (with the same sprites), but
with height tweaking and a preview panel. Also, written in javascript instead of Adventure Game Studio.

![Editor window](editor/editor.png)