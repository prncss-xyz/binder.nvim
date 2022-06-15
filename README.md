# Binder

Binder is a small library to help enforce consitent and readable neovim bindings. It does so by adding a light morphological layer (reduplication, prefix) and some tools to compose bindings in meaningful ways. It is still mostly for my personal usage, although the code is quite simple and should be easy to understand.

Current approch use functions rather than data structure. While this is very pleasant to write and read, it leads to less useful error messages. We could impove this by having the functions create intermediate table representations.
