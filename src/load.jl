function load_case(case_path::String)
    # config
    df_config = CSV.read(joinpath(case_path, "config.tsv"), DataFrame, delim = "\t", stringtype=String)
    n_job = df_config[1, "N_job"]
    is_sequential = df_config[1, "Sequential"] == 1
    plot_range = df_config[1, "Plot_range"]

    # machines
    df_machines = CSV.read(joinpath(case_path, "machines.tsv"), DataFrame, delim = "\t", stringtype=String)
    machines = Vector{Machine}()
    for i = 1:size(df_machines)[1]
        push!(machines, Machine(i, df_machines[i, :Machine_type], df_machines[i, :Machine_name]))
    end

    # job definitions
    df_operations = CSV.read(joinpath(case_path, "operations.tsv"), DataFrame, delim = "\t", stringtype=String)
    df_dependency = CSV.read(joinpath(case_path, "dependency.tsv"), DataFrame, delim = "\t", stringtype=String)
    df_tcmb = CSV.read(joinpath(case_path, "tcmb.tsv"), DataFrame, delim = "\t", stringtype=String)

    jobs = [Job(job_id, [], [], []) for job_id = 1:n_job]

    for job_id = 1:n_job
        for i = 1:size(df_operations)[1]
            push!(
                jobs[job_id].operations,
                Operation(
                    job_id,
                    df_operations[i, :Operation_ID],
                    df_operations[i, :Compatible_machine],
                    df_operations[i, :Processing_time] * 60,
                    df_operations[i, :Note],
                ),
            )
        end

        for i = 1:size(df_dependency)[1]
            push!(jobs[job_id].dag, (df_dependency[i, :Operation_ID_1], df_dependency[i, :Operation_ID_2]))
        end

        for i = 1:size(df_tcmb)[1]
            push!(
                jobs[job_id].constraints,
                TCMB(
                    df_tcmb[i, :Operation_ID_1],
                    Symbol(df_tcmb[i, :Point_1]),
                    df_tcmb[i, :Operation_ID_2],
                    Symbol(df_tcmb[i, :Point_2]),
                    df_tcmb[i, :Time_constraint] * 60,
                ),
            )
        end
    end

    # create batch
    batches = Vector{Batch}()
    if is_sequential
        for job_id = 1:n_job
            push!(batches, Batch([jobs[job_id]]))
        end
    else
        push!(batches, Batch(jobs))
    end

    return machines, batches, plot_range
end
