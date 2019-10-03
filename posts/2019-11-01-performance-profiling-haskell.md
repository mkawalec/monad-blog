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

hs2ps is a bit meh, didn't really show anything of use

Why random is slow and why I've used a different version of the library?

https://blog.jez.io/profiling-in-haskell/

Talk about the memory layout

Reading the core to check optimization status
