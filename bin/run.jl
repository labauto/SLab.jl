using Base.Filesystem
using SLab

case = if length(ARGS) == 0
    joinpath(@__DIR__, "..", "examples", "case_1", "case_1_A")
elseif length(ARGS) == 1
    ARGS[1]
else
    throw(ArgumentError("Too many ARGS."))
end

case_path = abspath(case)
case_name = last(splitpath(case_path))

SLab.main(case_name, case_path)
