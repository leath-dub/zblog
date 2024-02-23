<link rel="stylesheet" href="https://unpkg.com/sakura.css/css/sakura.css" type="text/css">

> Note: After running the numbers, turns out this format is 18.75% smaller than a raw binary. 

# PRUNE Header
```
*------------------------------------------------------------------*
| Bytes  | Description                                             |
|==================================================================|
| 4      | 32-Bit BE unsigned integer ("Hard Normal" tree height)  |
|--------+---------------------------------------------------------|
| 2      | 16-Bit BE unsigned integer (Chunk Size)                 |
|--------+---------------------------------------------------------|
| 2      | 16-Bit BE unsigned integer (Layer Count)                |
*------------------------------------------------------------------*
```

The "Hard normal" tree Height determines how many hard normals there are.
This determines the nomal density. This entry should however, never exceed the value of 134209536, for this will then mess up the decryption process in the UNIT ENTRY.
> Changing the size of this will change the size of the Hard Normal ENCRYPT in the Unit Entry.

Chunk Size determines how many units there are in a chunk.
This is the value which the renderer uses to determine how much to read from the file.

Layer Count determines how many layers there are in this file.
Helps the renderer track the percentage of the file loaded.

> Chunk Size * Layer Count must always be greater or equal to the number of vertecies of the original file(The one that gets converted).


# PRUNE Unit Entry
```
*----------------------------------------------------------------------*
| Bytes  | Description                                                 |
|======================================================================|
| 8      | 64-Bit BE Floating Point Number (x) |                       | 
|----------------------------------------------x                       |
| 8      | 64-Bit BE Floating Point Number (y) | Vertex Vector3        | 
|----------------------------------------------x                       |
| 8      | 64-Bit BE Floating Point Number (z) |                       |
|----------------------------------------------------------------------|
| 4      | 32-Bit BE unsigned integer (Hard Normal ENCRYPT)            |
|----------------------------------------------------------------------|
| 4      | 32-Bit BE Floating Point Number (x) |                       | 
|----------------------------------------------x UV Coordinate Vector2 |
| 4      | 32-Bit BE Floating Point Number (y) |                       | 
|----------------------------------------------------------------------|
| 2      | 16-Bit BE unsigned integer (index)  |    |                  | 
|----------------------------------------------x A  |                  |
| 2      | 16-Bit BE unsigned integer (layer)  |    |                  | 
|---------------------------------------------------x                  |
| 2      | 16-Bit BE unsigned integer (index)  |    |                  | 
|----------------------------------------------x B  |                  |
| 2      | 16-Bit BE unsigned integer (layer)  |    |                  | 
|---------------------------------------------------x  Parent Quad     |
| 2      | 16-Bit BE unsigned integer (index)  |    |                  | 
|----------------------------------------------x C  |                  |
| 2      | 16-Bit BE unsigned integer (layer)  |    |                  | 
|---------------------------------------------------x                  |
| 2      | 16-Bit BE unsigned integer (index)  |    |                  | 
|----------------------------------------------x D  |                  |
| 2      | 16-Bit BE unsigned integer (layer)  |    |                  | 
*----------------------------------------------------------------------*
```

"Vertex" is the vertex vector.
"UV Coordinate" is the UV coordinate.
> This may get scrapped if time does not permit their implementation.

## Hard Normal Encryption

The following function "to_normal" is used to decode the normal vector from the HARD NORMAL encryption.

```
func sum_to(n : int) -> int:
	return roundi(n * (n+1) * 0.5)

func reverse_from( s : int ) -> int:
	return floori( (sqrt(1 + 8 * s) - 1) * 0.5 )

func to_normal(index : int, height : int) -> Vector3:
	var level = reverse_from(index)
	var level_index = sum_to(level)
	var x = index - level_index
	var y = height - level
	var z = height - y - x
	return (Vector3(x,y,z) / height).normalized()
```

Here "index" is the value pulled from the UNIT ENTRY.
"Height" corresponds to the "Hard Normal Tree Height" from the header file.

## Parent Quad

Parent Quad is this formats alternative to indecies array.
It is used to reconstruct the faces from the vertecies using their indicies.
The order of the values matters since:

```
    For a face ABC, and BCD, their quad would be A-BC-D.
    The two triangles share a mutual side BC; called a bridge.
    The remaining values are called the Docks.
    
    The vertex being added is a point E.
    Quad(A-BC-D)  +  Vertex(E) = {Triangle(EAB), 
                                  Triangle(EBC), 
                                  Triangle(ECD), 
                                  Triangle(EDA)}

    The pattern here is AB, BC, CD, DA; hence ordering matters for surface reconstruction.
```

Each Quad index has 2 integers in it, due to the structure of the Weaver Class.
It is expected that each chunk of data will be an array within an array.
Hence the vertecies will not be accesed by `vert[index]`, but by `vert[chunk][index]`.
