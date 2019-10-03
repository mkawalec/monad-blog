---
title: Performance profiling in Haskell
author: Michał Kawalec
uuid: performance-profiling
---

I gave a talk a year ago about speeding up a simple raytracer I wrote in Haskell from being around thirty times slower than C, to about half of the speed. It received a great reception and I promised to write the findings up in a form of a blogpost, but I only recently found the time to do that, and here it comes.

Let's talk about it exactly with the example of the raytracer, showing how it worked

Tools: 
  - threadscope
  - ghc-gc-tune
  - profiteur

hs2ps is a bit meh, didn't really show anything of use unless for memory usage

Why random is slow and why I've used a different version of the library?

https://blog.jez.io/profiling-in-haskell/

Talk about the memory layout
  - how we have pointers to constructors
  - how UNPACK solves that issue of nonlocality
  - you can now unpack sum types!

Practical guide on reading Core, you can see these other places for a better reference of Core features

Reading the core to check optimization status
  - dump it with -ddump-simpl
  - evaluates at case expressions
  - explain strictness annotations
  - usage analysis and unpacking
  - worker/wrapper transformation (generates a version of a function that accepts unpacked parameters)
    - a maximum of ten parameters for a function when it is unpacked
  - inlining functions is useful, but not always

Try using LLVM
