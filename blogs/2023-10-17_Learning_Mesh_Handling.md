<link rel="stylesheet" href="https://unpkg.com/sakura.css/css/sakura.css" type="text/css">

# Learning how to handle meshes

Hi, Nemo here. 
As you may or maynot know, we attempting to inovate the field of Graphics by introducing a new approach to rendering meshes.
The work here is segregated into two independant parts: The renderer - for demonstration purposes - and the converter; the piece of software that facillitates the desired optimizations.

The converter is my responsibility... and a daunting one at that.
So, where do I start? 

I reasoned that since the converter consists of 3 parts, each dependant on the prior, ...
    1. Reader - that reads OBJ meshes
    2. Algorithm - that somehow reduces the mesh storage requirement, and improves runtime performance
    3. Writer - that stores data into a custom file format
...the most important place to start is the algorithm itself.
It dictates the format of the result file, and is at the moment the biggest unknown about the project.

The algorithm, however, depends on the reader to convert mesh data into an object I can play around with.
Not only that, but it would also require a renderer to be complete to test adequately.

No problem, I know just the environment to develop it in.

# So, how does Godot handle meshes?

For the uninitiated, Godot is a Game Engine.
For my purposes, it is an integrated environment with mesh loading, handling, and rendering already implemented.
Thus, I can focus on the algorithm exclusively.

Most importantly, it also serves as my teacher.
How is the mesh data stored, and handled?
Well, lets see how Godot does it.

## What is a mesh?

If you thought something along the lines of "a list of vertecies", you get half a cookie.
A mesh in godot is represented as an array of arrays.

To paint you a picture, imagine a cube.
This cube has vertecies (points; 8 of them), so you need an array of vectors to store vertecies.
But vertecies alone do not a cube make.
This cube has a surface, made up of faces.
A face - or a triangle if you will - is made up of 3 vertecies connected together.
So we need another array to represent the connections between vertecies.
Given that we already have an array of vertecies, we can use their indexes to represent which vertex we are reffering to.
Thus, we get an array of indecies; grouped in threes, since 3 points make one face.

With this, we have a 3D object in space. 
Small problem though, we cannot see it.
A light value of a pixel is determined by looking at how the light refracts from the face of the mesh.
What determines the refraction of light?
The normal vector of the face, of course.
Naturally, we need an array of normals too.

Now, we can see the mesh.
It is a bit bland - painted in black, white and values in between - but we can at least see its contour, and depth.

There are other values that go into a mesh, like UVs which map textures to the surface of the mesh, but that is not relevant to us at the moment.

But wait a minute.
If you stop to think about it, how to we know which normal vector in the normals array, belongs to which vector in the vertecies array?
Surely, the groupings matter?

Here begins what I fear will be a reoccuring theme of these blogs.
First element in vertecies array, is grouped with the first element in the normals array... and every other array for that matter.  
Ordinality matters.


## Picture this!

All this theory is nice and all, but what does all this look like in practice?
Well, my learning went thusly...

First, I generated a mesh from scratch.
The fastest way to learn is to fiddle around and find out.
So I created the values manually, and updated the scene to see what happened.

Godot ended up having a good deal of failsafes.
For one, it can calculate the normals, and indecies automatically.

> Note to self, check out THAT particular part of Godot source code.

A neat safety net... which I imediately turned off.
If I am gonna create my own renderer, then I need to know mesh handling inside and out.

Second test, I created a little script to create a sphere.
It worked.

Now that warm up is ready, lets get to the real thing.


## Oh, Suzanne why must you hurt me so?

Next up, I attempt to duplicate a mesh.
I am working on a converter after all.
Godot is handling the reading of the files for me, but I still need to modify that data and see the effects.

I was surprised to find out that the `ArrayMesh` class I have been using thus far, has no capacity to modifiy its data.
You can't even read the data of the imorted mesh.
That work is instead delegated to the `MeshDataTool`.

It seamed weird to me at the start.
But it makes sense design wise.
`ArrayMesh` is a container; it only concerns itself with filling itself up, and giving out whatever data the renderer needs to display the object.
The game developer rarely needs to edit the meshes he imports, and the functionality I expected it to have would make this frequently used class heavier than it needs to be.

Better to have another class handle modifying than to introduce overhead system wide.

> Maybe our project will suffer from same problems this solution solves? Keep in mind.

System design aside, problems were had.
While copying data, I could not figure out how to copy over the indicies data.
So I saw were dots in space, and not much more.
The shading was working, so I conclude normals were copied over sucessfuly.

I haven't checked the UVs, but texturing the object is out of the scope of this project...
but mayhaps not out of the realm of possibilities.

### Tangent on UV mapping
UV mapping is how the vertecies of a 3D mesh gets mapped onto a 2D texture.
Each vertex(Vector3) has a Vector2 value that describes a point on said 2D texture.
The texture gets mapped onto the face by interpolating between 3 vertecies, and their corresponding mappings on the texture, and picking up the color(normal, bump, etc.) value and drawing it on screen.

Ok, lets say, hypothetically, for the sake of the argument, we removed certain points from a mesh.
The UV data on the remaining vertecies would remain the same.
So, the interpolation process would still work.

I don't know what visual glitches that would cause, but it seems like a simple feature, should time permit.   


## Back to Suzanne..
There was another simple test I wanted to run, now that I had access to an imported mesh.
I tried some basic filtering of the data.
I wanted to draw a bounding box around the Suzanne mesh.
So I filtered for the "extremes"(TM); the points which have the highest and smallest x,y, and z values.
Take those, and then get the minimum and maximum of the extremes, and you get two points, which create a diagonal of the bounding box.

Simple enough.
Which is great, since I expect the dissolution algorithms will all depent on this form of filtering to create the desired layers of detail.

# Whats next?
That about covers the first run of tests.
I will sit down to come up with candidates for "dissolution" algorithms.

I also have some ideas on how the data inside the custom format should be organized.



