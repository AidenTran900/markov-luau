---
sidebar_position: 1
---
# MarkovLuau

A Luau port and extention of **MarkovJunior** [(read more)](https://github.com/mxgmn/MarkovJunior). This package is mainly focused towards Roblox development. However, it is headless with no Roblox globals (`Random`, `Vector3`, `Instance`, `game`), file reads, or image decoding.

## Features
- **Programmatic DSL**: The `Author` module that allows building models and rule sequences directly in code.
- **Time Travel**: A snapshot driven `InterpreterState` that captures grid states during generation for step-by-step playback.
- **Grid Cell Locking**: A `Grid.LockMask` feature that allows predefined layout bounds to be locked, meaning rules can read them but not overwrite.

## What about the original XML?
*Don't want to use DSL?* An XML parser is included so you can return a string with XML and it will work just fine.
Every model in [MarkovJunior](https://github.com/mxgmn/MarkovJunior) should run, though things may look different due to different implementations of Random.
