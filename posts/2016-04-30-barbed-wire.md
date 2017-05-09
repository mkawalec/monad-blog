---
title: Programming with bananas and barbed wire. Part 1
author: Michał Kawalec
---


This post is the first in a two-part series on recursion schemes. Here I
want to build intuiton and understanding of what recursion schemes are
and how to write them yourself. In the second part we'll explore Ed
Kmett's
[recursion-schemes](https://hackage.haskell.org/package/recursion-schemes-5.0.1/docs/Data-Functor-Foldable.html)
library to show you how to use recursion schemes in real-life Haskell
code. Examples in the following text are intentionally kept as simple as
possible to aid in understanding of underlying ideas more than the
examples themselves. Let's jump right in.


### Expressing recursion

We usually write recursive data types like 
  
    data Expr = Const Int
              | Add Expr Expr
              | Mul Expr Expr

It's a common way of writing a syntax tree, but it's not without
downsides. Consider the following function that pretty-prints a tree
made from this datatype.

    print :: Expr -> String
    print (Const i) = show i
    print (Add a b) = print a ++ " + " ++ print b
    print (Mul a b) = print a ++ " * " ++ print b

This is the usual way of defining recursion we're used to everywhere, we
define it explicitly. It may not be optimal from the perspective of code
readability with more complex recursion. There is also a possible
performance penalty as GHC is way better in optimizing non-recursive
then recursive code.


Can we do better? Possibly. Consider the following data type where
we're using a type parameter for encoding recursion.

    data ExprF a = Const Int
                 | Add a a
                 | Mul a a
                 deriving (Show, Eq)

The idea here is that we will use something called a 'fix point' of a
functor to encode recursive behavior inside `a` somehow. Before we get
to that, let's prove our type is indeed a functor. To do that we have to
implement `fmap` that abides by the functor laws. I propose the
following fmap

    fmap f (Const i) = Const i
    fmap f (Add a a) = Add (f a) (f a)
    fmap f (Mul a a) = Mul (f a) (f a)

So by applying `f` with `fmap` we unpack a level out of a functor, apart
from the `Const` case where we return the thing itself. The reason for
passing `i` through is that `fmap` has type `a -> b`, but the type of
`i` is always `Int`, so we can't match the types in general.

Our good old functor laws are

    fmap id == id
    fmap (f . g) == fmap f . fmap g

To check that the first law is fulfilled, insert `id` for the function
`f` and the proof will flow from definition above. The second case for
`Add` will look as follows. It's the same for `Mul` since they have the
same structure.

    Add (f . g $ a) (f . g $ b) = fmap f (Add (g a) (g b)) = fmap f .
    fmap g $ Add a b

so it's fulfilled as well. Of course we can skip this bit in GHC thanks
to `DeriveFunctor` extension that allows us to derive `fmap`
autonomously.

### Representing our type as a fixpoint

We have a type `ExprF a`, which we know is a functor. We expect to
insert a Fix Point as `a` to get some deeper insight into the nature of
recursion, but what is that fix point?

    data Fix f = Fix (f (Fix f))  --or
    data Fix f = Fix {outF :: f (Fix f)}

In mathematics a fix point is an element of a function that is mapped
to itself by that function. If we expand one layer from `Fix f`, the
inner application, we get

    Fix (f (Fix f)) = Fix (f (Fix (f (Fix f))))

and we can do it forever. So `Fix f` is an infinite chain of `Fix`
applications and infinite chains don't care about one more application.
If we apply `Fix f` to `Fix f`, we get `Fix f` again and that's what is
meant by a fixpoint in this context.

Let's define a simple syntax tree in terms of the initial `Expr`

    Mul (Add ((Const 2) (Const 2))) (Const 2)

We should be able to represent the same thing with our `ExprF a`. Let's
start with the innermost `Const`

    Fix $ Const 2

Checking the types checks out

    > :t Fix $ Const 2
    Fix $ Const 2 :: Fix ExprF

We don't have to write an infinite chain because `Const` doesn't have
any `a`s in it's type definition. To get the whole thing we have to wrap
inside `Fix` on each level

    let fixedExpr =
    Fix (Mul (Fix (Add (Fix $ Const 2) (Fix $ Const 2))) (Fix $ Const 2))

The types check out again. I bet this was easier than it looked like at
the beginning of this story.

### Algebras

An algebra is an 'unwrapping' function.

    type Algebra f a = f a -> a

So for our `ExprF` type applying it to `String` will give us an algebra
`ExprF String -> String` 

    printAlg :: ExprF String -> String
    printAlg (Const i) = show i
    printAlg (Add a b) = "(" ++ a ++ " + " ++ b ++ ")"
    printAlg (Mul a b) = a ++ " * " ++ b

Wait, but it cannot be of any use, I can hear you say, we don't have any
way of applying that function unwrapping strings into strings to our
`fixedExpr`. Fear not!

### Catamorphisms

    cata :: Functor f => (f b -> b) -> Fix f -> b
    cata f = f . fmap (cata f) . outF

Calling `cata printAlg fixedExpr` gives `"(2 + 2) * 2"`. WOW! The first
time I got this I got so excited, this is amazing. Awesome. How does it
work? `outF` unwraps one level from `fixedExpr` then `fmap` which we
wrote some time ago recurses inside. When it gets to the leave which are
`Const i`, it converts each to the string. Then `f`s level up are
called, but they already have their arguments as strings. We've
eliminated recursion from our functions altogether! The only thing we
had to define was what happens to a single element of `ExprF String`.

We've achieved so much so easily, can we get an integer value for the
operation defined by same tree? We just need a simple new algebra:

    getValue :: ExprF Int -> Int
    getValue (Const i) = i
    getValue (Add a b) = a + b
    getValue (Mul a b) = a * b

    cata getValue fixedExpr => 8

Notice how again we just have to describe what happens to a single
element and all the internal types are the same. This keeps our code
concise and fast.

### Anamorphism

We can abstract away folds, can we unfold from a single value using a
similar scheme? Sure we can. For that we need an opposite of algebra, a
coalgebra

    type Coalgebra f a = a -> f a

    unwrap :: Coalgebra ExprF Int
    unwrap i
      | i < 4     = Add (i + 1) (i + 2)
      | otherwise = Const i

Anamorphism is a kind of opposite of a catamorphism, so let's see what
we get if we just flip functions around in the catamorphism. We have to
remember to wrap where cata unwraps:

    ana f = Fix . fmap (ana f) . f
    
    ana unwrap 1 => No instance for (Show (Fix ExprF)) arising from a use of ‘print’

Oh, there's no automatic way of printing `Fix`, which may be infinite.
But we know how to print it, just use our catamorphism:

    cata printAlg $ ana unwrap 1 => "(((4 + 5) + 4) + (4 + 5))"

Nice.

### Paramorphisms

Notice that neither of these functions has access to the original
structure. Stages higher up in a catamorphism (fold) only see the
pretty-printed versions of elements down the tree, if we're creating a
string-based representation. In many real-world tasks this is not enough
and we need access to the original values along with their output
representations. It would be a bit silly to parse output strings when
folding and it would negate any possible advantages of recursion
schemes.

Algebras that carry that information are called R-Algebras

    type RAlgebra f a = f (Fix f, a) -> a

So instead of just accepting an element inside a functor, we get a tuple
with the original entry and the pretty-printed element. A recursion
scheme accepting this type is called a paramorphism

    para :: forall f, a . (Functor f) => RAlgebra f a -> Fix f -> a
    para rAlg = rAlg . fmap fanout . outF
      where fanout :: Fix f -> (Fix f, a)
            fanout t = (t, para rAlg a)

Notice how types perfectly match up, so much so that we can almost write
these schemes by intuition. If you're typing this in in your ghci,
enable `ScopedTypeVariables`

A cool example of a paramorphism would be to sum the additions together,
if it turns we want to shorten the output for some important reason

concatSums :: RAlgebra ExprF String
concatSums (Const i) = show i
concatSums (Add (aExpr, _) (bExpr, _)) = show $ cata getValue aExpr + cata getValue bExpr
concatSums (Mul (_, a) (_, b)) = a ++ " * " ++ b

Here we've used both catamorphism for wrapping up the sums and
paramorphism for neatly doing everything in one step. 

Notice how `Const i` behaves differently then `Add` and `Mul`. We can
see why it is so from the definition of `fmap` above. `fmap something
(Const i)` equals `Const i` from definition, so it allows us to populate
leaves in the tree without calling `fanout` and have a neat starting
point for providing two arguments to `Add` and `Mul`

Coolness.

### Summing up

We've learnt how to abstract recursion away to transform recursive code
into one that exploits recursion inherently present in the datatype
itself. We now know what a fix point of a functor is and can write
five different algebras before coffee. If you have a minute, please let
me know how this tutorial worked for you at
[michal@monad.cat](mailto:michal@monad.cat)

### Next part

In part 2 we will explore the
[recursion-schemes](https://hackage.haskell.org/package/recursion-schemes-5.0.1/docs/Data-Functor-Foldable.html)
library to move our understanding into the real world Haskell. The ideas
will be broadly the same, with some magic sauce to make these
functions even more generic. You can still use what you've learned here
in your code as is though, so feel free to play with it.
