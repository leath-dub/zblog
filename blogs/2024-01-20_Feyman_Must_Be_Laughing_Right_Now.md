<link rel="stylesheet" href="https://unpkg.com/sakura.css/css/sakura.css" type="text/css">

> The first principle is that you must not fool yourself, and you are the easiest person to fool.
> Richard P. Feynman

# A Lesson in Optimism

Sup, its Nemo again.

I severely overestimated the Weaver algorithm.
As I was testing out one of the dissolution algorithms, I noticed some vertecies were being lost.
I debugged the memory, and found that the Disolver did not drop them.
I then turned my gaze upon the next link in the chain, just to find my belowed Weaver.

I sampled the output, and tried to run the algorithm by hand.
And sure enough, there was a hole.

Reason? The weaver stops iterating further down the layers once it finds a layer without a single candidate.

This leads to a few problems:

## Missorting
```
[5,10] - L1
[8,11] - L2
[1, 2] - L3
```
Oberve the above layer configuration.
The iterator would start at 5 in L1, and then search the second layer for candidates.
It would find none; it would move on to 10.
This would result in [5,1,2,8,10,11] being returned.
As you may notice, this is not sorted correctly.

But nothing was lost here, now was it?


## Dropping elements
```
[10, 20] - L1
[15    ] - L2
[25, 28] - L3
```
Observe the following configuration.
The result here would be [10,15,20].
25 and 28 are completely ignored.

# How could this happen?

I looked back at the test data I ran when I first implemented the algorithm.
I may or may not have fed the algoritm data which was guaranted to work.
A galactic lapse in judgement on my part.
I might have gotten a bit over excited on the prospect of closing this chapter of the development story.


# But in my baby's defence

In light of this dissapointing reality, I analysed the algorithm with a new, sceptical eye.
What I found was, that, the algorithm is not wrong, but rather limited in what it can weave.
It works perfectly for two layers.
But cracks on any more.

So, if one part can be done right, mayhaps I can salvage something here.
Weaver has this beatiful property of offering easy traversal.
Has no memory overhead, and maintains near random-access speeds.
This is perfect for a renderer which needs to iterate through the mesh data often.
It also provides one of the core features of this project; chunkability.
Or, rather, I hoped it would.

These are all desirable properties, and I cannot give them up without a fight.

# Why not use trees?

The problem Weaver is meant to solve HAS been solved before.
Just use trees; 2-3 trees to be exact.
Why haven't I opted for them?
Adding layers is easy; removing them, a philosophy.
It would also create a complexity shift, from covert-time into runtime.
The memory usage would be lower on average, but with a significant impact on render speeds.
I am prepared to make that tradeoff, but within reason.

# So, what next?



