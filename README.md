# PPMagic
Godot post processing effects using the new CompositorEffect stack in 5.3

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
They're intentionally not fullscreen, so you can see the settings used for each of them
## Game Scene Examples
![image1](https://i.ibb.co/bPgLMd5/spaceship-high-alpha1.png)
![image2](https://i.ibb.co/718m2wc/spaceship-low-alpha1.png)
![image3](https://i.ibb.co/KXB36dF/spaceship-low-alpha2.png)
![image4](https://i.ibb.co/mXCt3yt/spaceship-foliage1.png)
![image5](https://i.ibb.co/WGyYWvf/spaceship-high-alpha2.png)
## Photo Examples(I don't have a good showcase scene, so this is just photos on a quad in Godot...)
![image1](https://i.ibb.co/L1y5LMp/photo1.png)
![image2](https://i.ibb.co/Fn4zQ1h/photo2.png)
![image3](https://i.ibb.co/7RPtjnx/photo3.png)
![image4](https://i.ibb.co/bm5Jcgf/photo4.png)
![image5](https://i.ibb.co/J3QBKK4/photo5.png)
