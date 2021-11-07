SLab.jl
========

The official implementation of the scheduling method for the S-LAB (scheduling for laboratory automation in biology) problem, introduced in [1].

## Requirements
Install the Julia language from [the official website](https://julialang.org/). The [detailed instructions for installation](https://julialang.org/downloads/platform/) is also available.

## How to run
1. Get the source code.
    1. If you are familiar with `git`, simply clone this repository and move into the directory.
        ```sh
        $ git clone https://github.com/labauto/SLab.jl
        $ cd SLab.jl
        $ pwd
        /path/to/SLab.jl
        ```
    2. Alternatively,
        1. Download [a zip archive](https://github.com/labauto/SLab.jl/archive/main.zip).
        2. Extract the archive (a directory named `SLab.jl-main` will be created).
        3. `cd` into the directory.
2. Install the dependency.
    1. Start the Julia REPL.
        ```sh
        $ julia --project=.
        ```
    2. Install the dependency.
        ```
        julia> using Pkg; Pkg.instantiate(); Pkg.precompile()
        ```
    3. Exit the REPL.
        ```
        julia> exit()
        ```
2. Run example cases.
    ```sh
    $ julia --project=. bin/run.jl examples/case_1/case_1_A
    ```
    If you see a message like `Jobs will be completed in XXX minutes`, the computation is done.

    __NOTE__ : Running the program in this way takes long time due to the JIT compilation of Julia scripts.
    See the next section to speedup the program.
3. The result is saved as a PDF file in `examples/case_1/case_1_A/case_1_A_result.pdf`.

## Speedup the computation (optional)
To simply invoke the `run.jl` script takes long time for compiling the scripts.
You can shorten this runtime overhead by "pre-compiling" the program.

1. _Windows_
    1. Start the Julia REPL.
        ```sh
        $ julia --project=.
        ```
    2. Create a sysimage.
        ```
        julia> using PackageCompiler
        julia> create_sysimage([:CSV, :Cbc, :DataFrames, :Dates, :JuMP, :Plots, :Serialization, :SLab], sysimage_path="SLab.dll", precompile_execution_file="bin/run.jl")
        julia> exit()
        ```
    3. Run using the sysimage.
        ```sh
        $ julia --project=. -J SLab.dll bin/run.jl examples/case_1/case_1_A
        ```
2. _MacOS_
    1. Install XCode Command Line Tools.
        ```sh
        $ xcode-select --install
        ```
    2. Start the Julia REPL.
        ```sh
        $ julia --project=.
        ```
    3. Create a sysimage.
        ```
        julia> using PackageCompiler
        julia> create_sysimage([:CSV, :Cbc, :DataFrames, :Dates, :JuMP, :Plots, :Serialization, :SLab], sysimage_path="SLab.dylib", precompile_execution_file="bin/run.jl")
        julia> exit()
        ```
    4. Run using the sysimage.
        ```sh
        $ julia --project=. -J SLab.dylib bin/run.jl examples/case_1/case_1_A
        ```
3. _Linux_
    1. Install gcc or clang.
    2. Start the Julia REPL.
        ```sh
        $ julia --project=.
        ```
    3. Create a sysimage.
        ```
        julia> using PackageCompiler
        julia> create_sysimage([:CSV, :Cbc, :DataFrames, :Dates, :JuMP, :Plots, :Serialization, :SLab], sysimage_path="SLab.so", precompile_execution_file="bin/run.jl")
        julia> exit()
        ```
    4. Run using the sysimage.
        ```sh
        $ julia --project=. -J SLab.so bin/run.jl examples/case_1/case_1_A
        ```

## References
[1] Itoh, TD. and Horinouchi, T., _et al_., "Optimal scheduling for laboratory automation of life science experiments with time constraints", _SLAS Technology_, 2021.
