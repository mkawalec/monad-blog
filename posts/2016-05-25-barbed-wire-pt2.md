---
title: Programming with bananas and barbed wire. Part 2
author: Michał Kawalec
uuid: barbedPart2
---

In the last part we've learnt about recursion schemes and how they work
internally. We've seen how fixed points can be used in conjunction with
functor types to express arbitrarily nested syntax tress. Finally, we
have seen how to split recursive operations on such fixed points into
a part that does the recursion and a nonrecursive function. That
function describes what happens to each single element of the tree and
operates on simple arguments. Because of that it's not only more
readable and versatile but also in many cases faster because of
optimizations applied by the compiler.

This time, what:
- is recursion-schemes lib
- are type families, with examples

So the reason for existence of type families is that instances of
typeclasses can do different things for different types. Like we're not
bound to lists of elements, we can do wildly different things for
different types. Can we be generic then though?

Hmm, it doesn't have to be in a typeclass?


- is the Base type family
- why mu and & nu?
- go through some folding, unfolding, combinators and distributive laws
-
