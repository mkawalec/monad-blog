---
title: Programming with bananas and barbed wire
author: Michał Kawalec
---

The idea for recursion schemes is pretty simple. We abstract over the
common parts of recursion and only specify what we do to each element.
Let's start with a simple example that uses the recursion-schemes
Haskell library.

How can we 

The plan for writing:
- what are recursion schemes
- what is an algebra?


- fixpoints of functors


We usually write recursive data types like 
  
  data Expr = Const Int
            | Add Expr Expr
            | Mul Expr Expr

It's perfectly valid to write a syntax tree this way, but writing a
function that operates on the whole tree is pretty tedious

    print :: Expr -> String
    print (Const i) = show i
    print (Add a b) = print a ++ " + " ++ print b
    print (Mul a b) = print a ++ " * " ++ print b

This works but keeps the `print` function intimately bound to the
data type with it's metastructure being replicated through the
explicit application of recursion.


Let's consider the following data type instead.

    data ExprF a = Const Int
                 | Add a a
                 | Mul a a
                 deriving (Show, Eq)

Then we can plug it into the fixpoint and it will terminate any time
there is a `Const` constructor! Is this a functor though? Let's
implement `fmap` and see.

    fmap f (Const i) = Const i
    fmap f (Add a a) = Add (f a) (f a)
    fmap f (Mul a a) = Mul (f a) (f a)

And the functor laws are

    fmap id == id
    fmap (f . g) == fmap f . fmap g

The first is trivially fulfilled, the second for the case of `Add`
looks like

    Add (f . g $ a) (f . g $ a) = fmap f (Add (g a) (g a))

so it's fulfilled as well.


## Representing our type as a fixpoint

Let's play a bit and define the following data type

    data Fix f = Fix (f (Fix f))  --or
    data Fix f = Fix {outF :: f (Fix f)}


So what does it mean that this element is a fixed point? In mathematics
a fixed point is an element of a function that is mapped to itself by
that function. To test it for our `Fix f`, we have to apply `Fix f` to

    Fix (f (Fix (f (Fix f)))) = Fix (f (Fix f))

which we achieve by f `(Fix (f (Fix f))) = f (Fix f)`, so this is truly
a fixed point of functor `f`. Let's assume we have the following syntax
tree

    Mul (Add ((Const 2) (Const 2))) (Const 2)

How can we represent it using the fixed point? Let's start with the
inner `Const`s

    (Fix $ Const 2)

That was easy. To get the whole thing we have to wrap inside `Fix` on
each level

    let fixedExpr =
    Fix (Mul (Fix (Add (Fix $ Const 2) (Fix $ Const 2))) (Fix $ Const 2))

Before we get to do something useful with that data structure, we need
to define one more thing

## Algebra

In mathematics an algebra is an 'unwrapping' function.

    type Algebra f a = f a -> a

    // Note to self: So how can we make a prettify function. Do we need
    something else than cata? Ah, the carrier type is arbitrary!

So for our `ExprF` type applying it to `String` will give us an algebra
`ExprF String -> String` like

    printAlg :: ExprF String -> String
    printAlg (Const i) = show i
    printAlg (Add a b) = "(" ++ a ++ " + " ++ b ++ ")"
    printAlg (Mul a b) = a ++ " * " ++ b

Wait, but it cannot be of any use, I can hear you say, we don't have any
way of applying that functions unwrapping strings into strings to our
`fixedExpr`. Fear not!

## Catamorphisms

    cata f = f . fmap (cata f) . outF

Calling `cata printAlg fixedExpr` gives `"(2 + 2) * 2"`. WOW! The first
time I got this I got so excited, this is amazing. Awesome. How does it
work? `outF` unwraps one level from `fixedExpr` then `fmap` which we
wrote some time ago recurses inside. When it gets to the bottom, that is
`Const i` it converts it to the string. Level up we have strings so our
function for `Add` acts on two strings. We've elliminated recursion
altogether!

We've achieved so much so easily, can we get an integer value for the
same tree? We just need a simple new algebra:

    getValue :: ExprF Int -> Int
    getValue (Const i) = i
    getValue (Add a b) = a + b
    getValue (Mul a b) = a * b

    cata getValue fixedExpr => 8

Which is true given the way we've bundled expressions together in the
above tree.

- anamorphisms
- paramorphisms
- using recursion schemes in Haskell with the recursion-schemes library
- similarity to the Free Monad
