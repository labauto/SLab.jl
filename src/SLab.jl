module SLab

using Cbc
using CSV
using DataFrames
using Dates
using JuMP
using Plots
using Plots.PlotMeasures
using Serialization

include("types.jl")
include("load.jl")
include("schedule.jl")
include("plot.jl")

function main(case_name::String, case_path::String)
    machines, batches, plot_range = load_case(case_path)

    # misc parameters
    current_time = DateTime(2021, 1, 1, 9, 0, 0)
    order_time = current_time + Hour(1)
    beta = 1 * 60
    scheduled_jobs = Vector{Job}()

    # run scheduling
    execution_time = 0
    for batch in batches
        execution_time = schedule(batch, scheduled_jobs, machines, order_time, beta, threads = 12)
    end
    print("Jobs will be completed in $(execution_time / 60) minutes.\n")

    # save and plot scheduling result
    serialize(joinpath(case_path, "$(case_name)_result"), (scheduled_jobs, machines, current_time))

    plot_schedule(
        scheduled_jobs,
        machines,
        xlims = (
            Dates.value.(current_time + Minute(50)),
            Dates.value.(current_time + Hour(plot_range)),
        ),
        size = (800, 600),
    )
    savefig(joinpath(case_path, "$(case_name)_result.pdf"))
end

end
