function epochsec2datetime(epochsec::Int64)::DateTime
    return Dates.epochms2datetime(Int64(epochsec * 1000))
end

function plot_schedule(
    scheduled_jobs::Vector{Job},
    machines::Vector{Machine};
    xlims = (-Inf, Inf),
    highlight_job_id = nothing,
    size = (600, 400),
)

    # axes
    plot(
        repeat([Inf], inner = length(machines)),
        reverse([m.name for m in machines]),
        yticks = (0.5:1:(length(machines)-0.5), reverse([m.name for m in machines])),
        ylims = (0, length(machines)),
        size = size,
    )

    for job in scheduled_jobs
        # operations
        color = job.id
        if !isnothing(highlight_job_id)
            if job.id == highlight_job_id
                color = :darkblue
            else
                color = :lightgray
            end
        end
        for op in job.operations
            xs = [epochsec2datetime(op.S), epochsec2datetime(end_time(op))]
            ys = repeat([machines[op.E].name], inner = 2)
            plot!(xs, ys, linewidth = 4, linecolor = color)
        end

        # operation dependencies
        for edge in job.dag
            xs = [epochsec2datetime(end_time(job.operations[edge[1]])), epochsec2datetime(job.operations[edge[2]].S)]
            ys = [machines[job.operations[edge[1]].E].name, machines[job.operations[edge[2]].E].name]
            plot!(xs, ys, linestyle = :dash, linecolor = :gray)
        end
    end

    plot!(
        legend = :none,
        title = "Scheduling Result",
        xlabel = "Date/Time",
        ylabel = "Machine",
        xlims = xlims,
    )
end
