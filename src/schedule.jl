function schedule(
    batch::Batch,
    scheduled_jobs::Vector{Job},
    machines::Vector{Machine},
    order_time::DateTime,
    beta;
    threads = 1,
    max_solutions = -1,
    big_m = 1e8,
)

    ################
    # Model
    ################

    scheduler = Model(Cbc.Optimizer)
    set_optimizer_attribute(scheduler, "threads", threads)
    set_optimizer_attribute(scheduler, "preProcess", "off")
    if max_solutions > 0
        set_optimizer_attribute(scheduler, "maxSolutions", max_solutions)
    end

    ################
    # Constants
    ################

    # machines
    M = length(machines)
    T = [m.T for m in machines]

    # operations
    N = get_N(batch)
    P = get_P(batch)
    C = get_C(batch)
    tau = get_tau(batch)

    # TCMB
    constraints = get_constraints(batch)

    # convert order_time to epoch sec
    t0 = Int64(Dates.datetime2epochms(order_time) / 1000)

    # scheduled operations
    scheduled_operations = vcat([job.operations for job in scheduled_jobs]...)
    N_prime = length(scheduled_operations)
    tau_prime = [op.tau for op in scheduled_operations]
    S_prime = [op.S - t0 for op in scheduled_operations]
    E_prime = [op.E for op in scheduled_operations]

    ################
    # Variables
    ################

    # start time
    @variable(scheduler, S[1:N] >= 0)

    # binary notation of which machine to process an operation
    F = Dict()
    for a = 1:N, m = 1:M
        if C[a] == T[m]
            F[a, m] = @variable(scheduler, binary = true)
        end
    end

    # shared-machine precedence relationship
    Q = Dict()
    for a = 1:N, b = 1:N, m = 1:M
        if a != b && C[a] == C[b] == T[m]
            Q[a, b, m] = @variable(scheduler, binary = true)
        end
    end

    # shared-machine precedence between a scheduled and an yet-to-be-scheduled operation
    R_precede = Dict()
    R_follow = Dict()
    for a = 1:N, b_prime = 1:N_prime
        if T[E_prime[b_prime]] == C[a]
            R_precede[a, b_prime] = @variable(scheduler, binary = true)
            R_follow[a, b_prime] = @variable(scheduler, binary = true)
        end
    end

    # variable for detecting lastly processed operation's end time
    @variable(scheduler, Omega, Int)

    ################
    # Constraints
    ################

    # 1-1: the end time of the entire schedule must larger than the end time of any operation
    for a = 1:N
        @constraint(scheduler, Omega >= S[a] + tau[a])
    end

    # 2-1: an operation is processed by and only by one machine
    for a = 1:N
        compatible = filter(m -> C[a] == T[m], 1:M)
        @constraint(scheduler, sum(F[a, m] for m in compatible) == 1)
    end

    # 2-2: a shared-machine precedence relationship exists between each pair of operations sharing the common machine
    for m = 1:M, a = 1:N, b = a:N
        if a != b && C[a] == C[b] == T[m]
            # AND circuit
            @constraint(scheduler, Q[a, b, m] + Q[b, a, m] <= F[a, m])
            @constraint(scheduler, Q[a, b, m] + Q[b, a, m] <= F[b, m])
            @constraint(scheduler, Q[a, b, m] + Q[b, a, m] >= F[a, m] + F[b, m] - 1)
        end
    end

    # 2-3: the shared-machine precedence relationship between a certain pair of operations can exist for at most one machine
    for a = 1:N, b = 1:N
        if C[a] == C[b]
            compatible = filter(m -> a != b && C[a] == C[b] == T[m], 1:M)
            @constraint(scheduler, sum(Q[a, b, m] for m in compatible) <= 1)
        end
    end

    # 2-4: a shared-machine precedence relationship must not violate the operation dependency
    for a = 1:N, b = 1:N, m = 1:M
        if P[a, b] == 1 && C[a] == C[b] == T[m]
            @constraint(scheduler, Q[b, a, m] == 0)
        end
    end

    # 2-5: a machine can process at most one operation at a time
    for a = 1:N, b = 1:N, m = 1:M
        if a != b && C[a] == C[b] == T[m]
            @constraint(scheduler, S[a] + tau[a] + beta <= S[b] + big_m * (1 - Q[a, b, m]))
        end
    end

    # 2-6: the dependency among operations must hold
    for a = 1:N, b = 1:N
        if P[a, b] == 1
            @constraint(scheduler, S[a] + tau[a] <= S[b])
        end
    end

    # 3-1: the absolute value of the difference between two operation boundaries is less than or equal to the maximum
    #      tolerable difference. There are four cases depending on the combination of boundaries
    for con in constraints
        a = con.operation_id_1
        b = con.operation_id_2
        if con.boundary_1 == :start && con.boundary_2 == :start
            @constraint(scheduler, S[a] - S[b] <= con.alpha)
            @constraint(scheduler, S[b] - S[a] <= con.alpha)
        elseif con.boundary_1 == :start && con.boundary_2 == :end
            @constraint(scheduler, S[a] - (S[b] + tau[b]) <= con.alpha)
            @constraint(scheduler, (S[b] + tau[b]) - S[a] <= con.alpha)
        elseif con.boundary_1 == :end && con.boundary_2 == :start
            @constraint(scheduler, (S[a] + tau[a]) - S[b] <= con.alpha)
            @constraint(scheduler, S[b] - (S[a] + tau[a]) <= con.alpha)
        elseif con.boundary_1 == :end && con.boundary_2 == :end
            @constraint(scheduler, (S[a] + tau[a]) - (S[b] + tau[b]) <= con.alpha)
            @constraint(scheduler, (S[b] + tau[b]) - (S[a] + tau[a]) <= con.alpha)
        end
    end

    # 4-1: an shared-machine precedence or following relationship must exist for any pair of operations sharing a
    #      common machine to process them, one of which is in a previously scheduled job and the other is in a new job
    for a = 1:N, b_prime = 1:N_prime
        if T[E_prime[b_prime]] == C[a]
            @constraint(scheduler, R_precede[a, b_prime] + R_follow[a, b_prime] == F[a, E_prime[b_prime]])
        end
    end

    # 4-2: a machine can process at most one operation at a time (case: an operation in a new job precedes another
    #      operation in a previously scheduled job)
    for a = 1:N, b_prime = 1:N_prime
        if T[E_prime[b_prime]] == C[a]
            @constraint(
                scheduler,
                S[a] + tau[a] + beta <= S_prime[b_prime] + big_m * (1 - R_precede[a, b_prime])
            )
        end
    end

    # 4-3: a machine can process at most one operation at a time (case: an operation in a new job follows another
    #      operation in a previously scheduled job)
    for a = 1:N, b_prime = 1:N_prime
        if T[E_prime[b_prime]] == C[a]
            @constraint(
                scheduler,
                S_prime[b_prime] + tau_prime[b_prime] + beta <= S[a] + big_m * (1 - R_follow[a, b_prime])
            )
        end
    end

    ################
    # Objective
    ################

    @objective(scheduler, Min, Omega)

    ################
    # Optimize
    ################

    JuMP.optimize!(scheduler)

    ################
    # Out
    ################

    # Time to start each operation
    S = [Int64(round(JuMP.value(S[a]))) + t0 for a = 1:N] # rounding might cause bug in the future

    # Machines selected for each operation
    E = zeros(Int64, N)
    for a = 1:N, m = 1:M
        if C[a] == T[m] && JuMP.value(F[a, m]) == 1
            E[a] = m
        end
    end

    set_schedule(batch, S, E)

    append!(scheduled_jobs, batch.jobs)

    return JuMP.value(Omega)
end
