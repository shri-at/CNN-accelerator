# CNN-accelerator

The project aims to successfully build synthesizeable verilog modules for a CNN accelerator

So far, a module that generates feature maps is done. It creates three output matrices each corresponding to the valid cross correlation between the set of kernels given as input and the input matrix. The module is mostly parametrizable except for fixed layer depth of 3.
