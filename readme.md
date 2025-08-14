# love-boids-gpu
A [Boids](https://en.wikipedia.org/wiki/Boids) algorithm implementation for [LÖVE](https://love2d.org/) Framework running mostly on GPU

The collision and boids math runs on GPU, using fragment shaders as general purpose compute units. **Now with LÖVE 12.0 compute shader support for massive performance gains!**

## Features
- **Fragment shader version**: Original implementation using fragment shaders as compute (LÖVE 11.x)
- **Compute shader version**: New blazing fast implementation using proper compute shaders (LÖVE 12.0)
- **Massive scale**: Support for up to 65,536 boids with compute shaders (vs 2,048 original limit)
- **10-30x performance improvement** with compute shader version

## Demo
The Demo shows interaction between Solid Balls and Boids:
- **Fragment shader version**: Up to 2,048 of each type
- **Compute shader version**: Up to 65,536 total particles!

Left/Right clicks add either Boids or Solid Balls:<br>
Watch the Video (click):<br>
[![Screenshot](doc/demo1.gif?raw=true)](doc/L%C3%96VE%20Boids%20GPU%20Demo%202020-12-30%2016-45-57.mp4?raw=true)<br>

Boids behaviour (i.e. __rules__) can be adjusted with values displayed at bottom left corner.

## Design
The implementation is Designed around following principles:
 - Minimize data transfer to and from GPU (sincs this is a real performance killer)
 - Make use of Buffer orphaning (use OpenGLs buffer management)
 - Boids are handled as Swarm, no information about indivuals are necessary (on CPU)