# PPMagic
Godot post processing effects using the new CompositorEffect stack in 4.3

DISCLAIMER: I'm not a graphics programmer by any means, so this might be unoptimized/doing weird things. I'm just sharing this because it looks cool, and there's very little resources on this new system in Godot.

Currently, the only effect added is an Anisotropic Kuwahara, with a bunch of exposed settings to achieve a range of painterly looks.

Also, this is an example of a multi pass shader, with a sobel, eigenvector and kuwahara pass, reading and writing to different buffers. Check the compositor_effects/fancy_kuwahara/fancy_kuwahara.gd to see how it's set up.

# Installation
Put the pp_magic folder into the res://addons folder of your project
# Usage
* On your Camera3D or WorldEnvironment node, on the Compositor field, add a New Compositor
* Click Add Element
* Select New FancyKuwahara
* Play with parameters to your liking - Note: The Kuwahara Radius can make this shader quite heavy, as the render time grows exponentially with the radius.
# Screenshots
They're intentionally not fullscreen, so you can see the settings used
## Photo Examples 
On a quad in Godot, because the effect works best on high detail scenes, that I currently don't have :( 3D scene examples further down

![image1](https://i.ibb.co/bm5Jcgf/photo4.png)
![image2](https://i.ibb.co/L1y5LMp/photo1.png)
## Game Scene Examples
![image1](https://i.ibb.co/bPgLMd5/spaceship-high-alpha1.png)
![image2](https://i.ibb.co/718m2wc/spaceship-low-alpha1.png)
![image3](https://i.ibb.co/WGyYWvf/spaceship-high-alpha2.png)
