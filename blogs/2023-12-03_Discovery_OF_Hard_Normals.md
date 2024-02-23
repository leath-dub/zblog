<link rel="stylesheet" href="https://unpkg.com/sakura.css/css/sakura.css" type="text/css">

# I am not exctly normal

Enemies, friends, and those still under review; Its Nemo.

Given how the goal of the project is an optimisiation, it made me wonder what other areas of the rendering pipeline should be put under review.
I was inspired by recent reading I did on Descrete Cosine Transform(DCT)(Topic recomended to me by Stephen Blott) and how it achieves incredible compression of image data.
While I wasn't able to think of now to adapt DCT to our goal, it still made me consider how the new file format could be made smaller if it intentionally let go of absolute precision values.

Looking at the data of the mesh, what were the canditdates?
The vertecies? I cannot map a (pseudo)infinite space into finite static values.
The UVs? Unknown behaviour. Lowering the maping precision may offset textures, and cause obvious visual glitches. Also, not scalable to different texture resolutions. 
Indecies? They represent how the vertecies connect together to form faces. Cannot map permutations to a low precision domain.

Which leaves normals.
Normals are vectors whose direction is perpendicular to the face they represent.
They are one of the fundamental data which makes up a mesh, because they are used to calculate how the light bounces from the face.
Shadows are not possible without them.
Without shadows, the only thing you can render is a silluete of the shape.

But here is the thing.
Normals are exclusively unit vectors.
Only its direction is relevant for the lighting calculations.

Now, I don't know about you, but if you asked me to imagine what all possible unit vectors drawn in space may look like, I'd wager its a sphere.
A perfectly round sphere, in fact.
I am not mathematicians, however; perfection cannot please me.
Perfection is hard... and computationally expensive.
I am more concerned about imperfection.
To be precise, how imperfect can a sphere get before I start to notice.

How exactly normal must normals be?


# This is hardly normal

Thus my grand quest begins... and lasts exactly 5 minutes; the time required for me to find a certain video.
You see, I hapened to have seen something similar being done a while back.
Albeit a different use case, [this](https://www.youtube.com/watch?v=lctXaT9pxA0) Sebastian Lague video deals with exactly what I need.
He is concerned with procedural planet generation, and stumbles upon an interesting question.
How to generate a sphere using vertecies?

There are a good few ways to do it, and I encourage you to watch Sebastian's video (only the first 5 minutes are relevant here).

However, among them all, only one stands out to me...

## Side-Subdivision Triangle Projection

So, imagine a triangle with all sides of the same length.
Imagine putting a point in the center of each side, and then conecting them.
You have now sucessfully subdivided the triangle by 2.
You can count 4 smaller triangles.

But more importantly, you can count 6 points.
Why should we care? 
Observe the pattern.
From top to bottom level we have: 1 point, 2 points, and 3 points; 6 points in total.
So, if we added another level of interconected smaller triangles, we would expect to have 10 points; 1 + 2 + 3 + 4 = 10.

More importantly, the points are equidistant from each other; exactly the property we wish to see in our sphere.
So, we, naturally, project the triangle onto one segment of the sphere; along with the above pattern.

## How does this relate to the low precision normals?

Well you see, the above pattern is predictable.
In other words, it is trivial to map an index to the exact point in the pattern.
To map an index to uniformly, equidistatantly distributed vector... given that we know how many points are inside the pattern.

So, how many points do we need?
Good question.

Since the difference between absolute precision, and low precision are up to perception, I just generated all the vectors to see what happened.
I say we could get away with 8256 vectors, but why stop there?

Since we are storing only an index, that means the entire vector (3 integers large) falls under one integer.
However, notice how the vectors are only generated in one quadrant?
We will need 3 bits reserved to flip the X, Y, and Z axis where needed.
So, including our 3 reserved bits, how many vector can a 16 bit number hold?
16384.
32 bit number?
1073741824.

Yeah, I think we have more than enough.

## What is up next?

While I have the mapping working, the approach isn't one that I am satisfied with.
I will try and minimize the calculations.
I expect that the normals will be stored as a vector structure when in working memory.
So, whatever decoding needs to be done, it needs only be fast enough to not slow down rendering when chunks are loaded.

