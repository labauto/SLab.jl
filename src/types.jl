"""
    SLab.Machine

Machine definition.
"""
mutable struct Machine

    """machine id"""
    id::Int64

    """machine type"""
    T::Int64

    """machine name"""
    name::String

end

"""
    SLab.Operation

Operation definition.
"""
mutable struct Operation

    """parent job id"""
    job_id::Int64

    """operation id"""
    id::Int64

    """compatible machine type"""
    C::Int64

    """process time in sec."""
    tau::Int64

    """start time"""
    S::Int64

    """machine id to process this operation"""
    E::Int64

    """note"""
    note::String

    function Operation(job_id::Int64, id::Int64, C::Int64, tau::Int64, note::String)
        new(job_id, id, C, tau, 0, 0, note)
    end

end

"""get end time of an operation"""
function end_time(op::Operation)::Int64
    if op.S == 0
        return 0
    else
        return op.S + op.tau
    end
end

"""
    SLab.TCMB

Time constraint by mutual boundaries
"""
mutable struct TCMB

    """operation id 1"""
    operation_id_1::Int64

    """boundary of operation 1 (begin or end)"""
    boundary_1::Symbol

    """operation id 2"""
    operation_id_2::Int64

    """boundary of operation 2 (begin or end)"""
    boundary_2::Symbol

    """maximum difference in time (sec.) between two boundaries"""
    alpha::Int64

end

"""
    SLab.Job

Job definition, containing a series of operations, dependency graph among operations, and TCMB.
"""
mutable struct Job

    """job id"""
    id::Int64

    """list of operations"""
    operations::Vector{Operation}

    """operation dependency graph"""
    dag::Vector{Tuple{Int64,Int64}}

    """time constraint by mutual boundaries"""
    constraints::Vector{TCMB}

end

"""
    SLab.Batch

To schedule multiple jobs simultaneously, combine those jobs into a single Batch.
"""
mutable struct Batch

    """list of contained jobs"""
    jobs::Vector{Job}

    """all operations in the jobs in a single vector"""
    operations::Vector{Operation}

    """conversion table from (job_id, op_id_in_job) to op_id_in_batch"""
    operation_indices::Dict{Tuple{Int64,Int64},Int64}

    function Batch(jobs::Vector{Job})
        operations = Vector{Operation}()
        operation_indices = Dict{Tuple{Int64,Int64},Int64}()
        for job in jobs
            for op in job.operations
                push!(operations, op)
                operation_indices[job.id, op.id] = length(operations)
            end
        end
        new(jobs, operations, operation_indices)
    end

end

"""get number of operations in a batch"""
function get_N(batch::Batch)::Int64
    return length(batch.operations)
end

"""get operation dependency graph in a batch"""
function get_P(batch::Batch)::Matrix{Bool}
    P = zeros(Bool, get_N(batch), get_N(batch))
    for job in batch.jobs
        for edge in job.dag
            P[batch.operation_indices[job.id, edge[1]], batch.operation_indices[job.id, edge[2]]] = 1
        end
    end
    return P
end

"""get compatible machine types of operations in a batch"""
function get_C(batch::Batch)::Vector{Int64}
    return [op.C for op in batch.operations]
end

"""get processing times for operations in a batch"""
function get_tau(batch::Batch)::Vector{Int64}
    return [op.tau for op in batch.operations]
end

"""get TCMB in a batch"""
function get_constraints(batch::Batch)::Vector{TCMB}
    constraints = Vector{TCMB}()
    for job in batch.jobs
        for con in job.constraints
            push!(
                constraints,
                TCMB(
                    batch.operation_indices[job.id, con.operation_id_1],
                    con.boundary_1,
                    batch.operation_indices[job.id, con.operation_id_2],
                    con.boundary_2,
                    con.alpha,
                ),
            )
        end
    end
    return constraints
end

"""set start time and machine id for each operation in a batch"""
function set_schedule(batch::Batch, S::Vector{Int64}, E::Vector{Int64})
    for a = 1:get_N(batch)
        batch.operations[a].S = S[a]
        batch.operations[a].E = E[a]
    end
end
