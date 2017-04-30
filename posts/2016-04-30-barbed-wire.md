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

    `type Algebra f a = f a -> a`

- fixpoints of functors

    We can write a fixpoint as 
    
    ```
    type Fix f = In (f (Fix f))  --or
    type Fix f = In {outF :: f (Fix f)}
    ```

    Here we can see that we have a fix point when adding one more layer
    of wrapping changes nothing, this data structure is infinite. How is
    this even useful then? There aren't that many infinite data
    structures in the real world after all.

    We usually write recursive data types like 
      
      data Expr = Const Int
                | Add Expr Expr
                | Mul Expr Expr
    
    It's perfectly valid to write a syntax tree this way, but writing a
    function that operates on the whole tree is pretty tedious

    ```
      print :: Expr -> String
      print (Const i) = show i
      print (Add a b) = print a ++ " + " ++ print b
      print (Mul a b) = print a ++ " * " ++ print b
    ```


    Let's think about a data type like

      data ExprF a = Const Int
                   | Add a a
                   | Mul a a

    Then we can plug it into the fixpoint and it will terminate any time
    there is a `Const` constructor! Is this a functor though? Let's
    implement `fmap` and see.

    ```
    fmap f (Const i) = Const i
    fmap f (Add a a) = Add (f a) (f a)
    fmap f (Mul a a) = Mul (f a) (f a)
    ```

    And the functor laws are
    ```
    fmap id == id
    fmap (f . g) == fmap f . fmap g
    ```
    The first is trivially fulfilled, the second for the case of `Add`
    looks like
    ```
    Add (f . g $ a) (f . g $ a) = fmap f (Add (g a) (g a))
    ```
    so it's fulfilled as well.




- using recursion schemes in Haskell
- cata fusion
- similarity to the Free Monad
