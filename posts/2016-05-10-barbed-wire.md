---
title: Programming with bananas and barbed wire. Part 1
author: Michał Kawalec
uuid: barbedPart1
---


This post is the first in a two-part series on recursion schemes. Here, I
want to build intuiton and understanding of what recursion schemes are
and how to write them yourself. In the second part we will explore Ed
Kmett's
[recursion-schemes](https://hackage.haskell.org/package/recursion-schemes-5.0.1/docs/Data-Functor-Foldable.html)
library, to show you, how to use recursion schemes in real-life Haskell
code. Examples in the following text are intentionally kept as simple as
possible, to aid in understanding of underlying ideas more than the
examples themselves. Let us jump right in.


### Expressing recursion

We usually write recursive data types like 
  
```haskell
data Expr = Const Int
          | Add Expr Expr
          | Mul Expr Expr
```

This is a common way of writing a syntax tree, but it is not without
downsides. Consider the following function that pretty-prints a tree
made from this datatype.

```haskell
print :: Expr -> String
print (Const i) = show i
print (Add a b) = print a ++ " + " ++ print b
print (Mul a b) = print a ++ " * " ++ print b
```

This is the usual way of defining recursion we are used to everywhere &mdash; we
define it explicitly. What if instead of pretty printing the syntax tree
we wanted to calculate a numeric value of an operation it describes? We
would have to write a function just like `print`, manually recursing
into individual elements. While there is a little chance of making an
error in this simple example, mistakes while writing recursive functions
are not unheard of. There is also a possible performance penalty, as GHC
is way better in optimizing non-recursive then recursive code.


Can we do better? Possibly. Consider the following data type, where
we are using a type parameter for encoding recursion.

```haskell
data ExprF a = Const Int
             | Add a a
             | Mul a a
             deriving (Show, Eq)
```

The idea here is that we will use something called a 'fixed point' of a
functor to encode recursive behavior inside `a` somehow. Before we get
to that, let us prove our type is, indeed, a functor. To do that, we have to
implement `fmap` that abides by the functor laws. I propose the
following `fmap`

```haskell
fmap f (Const i) = Const i
fmap f (Add a a) = Add (f a) (f a)
fmap f (Mul a a) = Mul (f a) (f a)
```

So by applying `f` with `fmap` we unpack a level out of a functor, apart
from the `Const` case, where we return the thing itself. The reason for
passing `i` through is that `fmap` has type `a -> b`, but the type of
`i` is always `Int`, so we cannot match the types in general.

Our good old functor laws are

```haskell
fmap id == id
fmap (f . g) == fmap f . fmap g
```

To check that the first law is fulfilled, insert `id` for the function
`f` and the proof will flow from definition above. The second case for

`Add` will look as follows. It is the same for `Mul`, since they have the
same structure.

```haskell
Add (f . g $ a) (f . g $ b) = fmap f (Add (g a) (g b)) = fmap f .
fmap g $ Add a b
```

so it is fulfilled as well. Of course, we can skip this bit in GHC thanks
to `DeriveFunctor` extension that allows us to derive `fmap`
automatically. We will reference this implementation later though, so
it's best if it is written down explicitly.


### Representing our type as a fixed point

We have a type `ExprF a`, which we know is a functor. This data type
looks a bit useless, given that the type itself depends on the amount of
levels of nesting

    > :t Const 2
    Const 2 :: ExprF a

    > :t Add (Const 1) (Const 2)
    Add (Const 1) (Const 2) :: ExprF (ExprF a)

And so on. Even worse, the type demands that all branches have the same
depth, so it looks effectively unusable. But I've mentioned fixed point
as something that can help encoding arbitrary recursive behaviour in
`a`, what is it?

```haskell
data Fix f = Fix (f (Fix f))  --or
data Fix f = Fix {outF :: f (Fix f)}
```

In mathematics, a fixed point is an argument of a function that is mapped
to itself by that function. If we expand one layer from `Fix f`, the
inner application, we get

```haskell
Fix (f (Fix f)) = Fix (f (Fix (f (Fix f))))
```

and we can do it forever. So `Fix f` is an infinite chain of `Fix`
applications, and infinite chains do not care about one more application.
If we apply `Fix f` to `Fix f`, we get `Fix f` again and that is what is
meant by a fixed point in this context.

Let us define a simple syntax tree in terms of the initial `Expr`

```haskell
Mul (Add ((Const 2) (Const 2))) (Const 2)
```

We should be able to represent the same thing with our `ExprF a`. Let us
start with the innermost `Const`

```haskell
Fix $ Const 2
```

Checking the types checks out

    > :t Fix $ Const 2
    Fix $ Const 2 :: Fix ExprF

We do not have to write an infinite chain because `Const` does not have
any `a`s in its type definition. To get the whole thing, we have to wrap
inside `Fix` on each level

```haskell
let fixedExpr =
Fix (Mul (Fix (Add (Fix $ Const 2) (Fix $ Const 2))) (Fix $ Const 2))
```

The types check out again. I bet this was easier than it looked like at
the beginning of this story.

### Algebras

An algebra is an 'unwrapping' function.

```haskell
type Algebra f a = f a -> a
```

So for our `ExprF` type, applying it to `String` will give us an algebra
`ExprF String -> String` 

```haskell
printAlg :: ExprF String -> String
printAlg (Const i) = show i
printAlg (Add a b) = "(" ++ a ++ " + " ++ b ++ ")"
printAlg (Mul a b) = a ++ " * " ++ b
```

Wait, but it cannot be of any use, I can hear you say. We do not have any
way of applying that function unwrapping strings into strings to our
`fixedExpr`. Fear not!

### Catamorphisms

```haskell
cata :: Functor f => (f b -> b) -> Fix f -> b
cata f = f . fmap (cata f) . outF
```

Calling `cata printAlg fixedExpr` gives `"(2 + 2) * 2"`. WOW! The first
time I got this I got so excited, this is amazing. Awesome. How does it
work? `outF` unwraps one level from `fixedExpr` then `fmap` which we
wrote some time ago recurses inside. When it gets to leafs which are
`Const i`, it converts each to a string. Then `f`s level up are
called, but they already have their arguments as strings. We have
eliminated recursion from our functions altogether! The only thing we
had to define was what happens to a single element of `ExprF String`.
This is an essence of functional programming, to compose a program from
multiple parts, each focused on doing it's own thing well.

We have achieved so much so easily, can we get an integer value for the
operation defined by same tree? We just need a simple new algebra:

```haskell
getValue :: ExprF Int -> Int
getValue (Const i) = i
getValue (Add a b) = a + b
getValue (Mul a b) = a * b
```

    cata getValue fixedExpr => 8

Notice how, again, we just have to describe what happens to a single
element, and all the internal types are `Int`s. This keeps our code
concise and fast. There is only one place where recursion happens, in
the definition of `cata`. Once we're sure it is without errors, the
possibility of making a mistake writing recursion disappears.


### Anamorphism

We can abstract away folds, but can we unfold from a single value using a
similar scheme? Sure we can. For that we need an opposite of algebra, a
coalgebra

```haskell
type Coalgebra f a = a -> f a

unwrap :: Coalgebra ExprF Int
unwrap i
  | i < 4     = Add (i + 1) (i + 2)
  | otherwise = Const i
```

Anamorphism is a kind of opposite of a catamorphism, so let us see what
we get if we just flip functions around in the catamorphism. We have to
remember to wrap where cata unwraps:

```haskell
ana f = Fix . fmap (ana f) . f
```
    
    ana unwrap 1 => No instance for (Show (Fix ExprF)) arising from a use of ‘print’

Oh, there is no automatic way of printing `Fix`, which may be infinite.
But we know how to print it, just use our catamorphism:

    cata printAlg $ ana unwrap 1 => "(((4 + 5) + 4) + (4 + 5))"

Nice.

### Paramorphisms

Notice that neither of these functions has access to the original
structure. Stages higher up in a catamorphism (fold) only see the
pretty-printed versions of elements down the tree, if we are creating a
string-based representation. In many real-world tasks, this is not enough,
and we need access to the original values along with their output
representations. It would be a bit silly to parse output strings when
folding, and it would negate any possible advantages of recursion
schemes.

Algebras that carry that information are called R-Algebras

```haskell
    type RAlgebra f a = f (Fix f, a) -> a
```

So instead of just accepting an element inside a functor, we get a tuple
with the original entry and the pretty-printed element. A recursion
scheme accepting this type is called a paramorphism

```haskell
para :: forall f a . (Functor f) => RAlgebra f a -> Fix f -> a
para rAlg = rAlg . fmap fanout . outF
  where fanout :: Fix f -> (Fix f, a)
        fanout t = (t, para rAlg t)
```

Notice how types perfectly match up &mdash; so much so that we can almost write
these schemes by intuition. If you are typing this in in your ghci,
enable `ScopedTypeVariables`

A cool example of a paramorphism would be to sum the additions together,
if it turns we want to shorten the output for some important reason

```haskell
concatSums :: RAlgebra ExprF String
concatSums (Const i) = show i
concatSums (Add (aExpr, _) (bExpr, _)) = show $ cata getValue aExpr + cata getValue bExpr
concatSums (Mul (_, a) (_, b)) = a ++ " * " ++ b
```

Here, we have used both &mdash; catamorphism for wrapping up the sums and
paramorphism for neatly doing everything in one step. 

Notice how `Const i` behaves differently then `Add` and `Mul`. We can
see why it is so from the definition of `fmap` above. `fmap something
(Const i)` equals `Const i` by definition, so it allows us to populate
leaves in the tree without calling `fanout` and to have a neat starting
point for providing two arguments to `Add` and `Mul`

Coolness.

### Summing up

We have learnt how to abstract recursion away to transform recursive code
into one that exploits recursion inherently present in the datatype
itself. We now know what a fixed point of a functor is and can write
five different algebras before morning coffee. If you have a minute,
please let me know how this tutorial worked for you. I would love to use
your feedback when writing part 2.

### Next part

In part 2, we will explore the
[recursion-schemes](https://hackage.haskell.org/package/recursion-schemes-5.0.1/docs/Data-Functor-Foldable.html)
library to move our understanding into the real world Haskell. The ideas
will be broadly the same, with some magic sauce to make these
functions even more generic. You can still use what you have learned here
in your code as is, though, so feel free to play with it.

### Further reading

In researching this post I have mainly used the following resources:

- [Understanding F-Algebras by Bartosz Milewski](https://bartoszmilewski.com/2013/06/10/understanding-f-algebras/)
- [Introduction to Recursion Schemes by Patrick Thomson](http://blog.sumtypeofway.com/an-introduction-to-recursion-schemes/)
- [Practical Recursion Schemes by Jared Tobin](https://jtobin.io/practical-recursion-schemes)
- [recursion-schemes library](https://hackage.haskell.org/package/recursion-schemes)
- [Functional Programming with Bananas, Lenses, Envelopes and Barbed Wire](https://pdfs.semanticscholar.org/fec6/b29569eac1a340990bb07e90355efd2434ec.pdf)

