# Evolution Strategy
# ==================
#
# Implementation: (μ/ρ(+/,)λ)-ES
#
# μ is the number of parents
# ρ ≤ μ the mixing number (i.e., the number of parents involved in the procreation of an offspring)
# λ is the number of offspring.
#
# Comma-selection (μ<λ must hold): parents are deterministically selected from the set of the offspring
# Plus-selection: parents are deterministically selected from the set of both the parents and offspring
#
function es(  objfun::Function, individual::T;
              initPopulation::Union{Nothing, Vector{T}} = nothing,
              initStrategy::Strategy = strategy(),
              creation::Function = (dims -> rand(eltype(T), dims)),
              recombination::Function = (rs -> rs[1]),
              srecombination::Function = (ss -> ss[1]),
              mutation::Function = ((r, m) -> r),
              smutation::Function = (s -> s),
              termination::Function = (x -> false),
              μ::Integer = 1,
              ρ::Integer = μ,
              λ::Integer = 1,
              selection::Symbol = :plus,
              iterations::Integer = 100*prod(size(individual)),
              verbose = false, debug = false,
              interim = false) where {T}

    @assert ρ <= μ "Number of parents involved in the procreation of an offspring should be no more then total number of parents"
    if selection == :comma
        @assert μ < λ "Offspring population must be larger then parent population"
    end

    store = Dict{Symbol,Any}()
    dims = size(individual)

    # Initialize parent population
    population = Array{T}(undef, μ)
    fitness = zeros(μ)
    for i in 1:μ
        if isnothing(initPopulation) 
            population[i] = creation(dims)
        else
            population[i] = initPopulation[i]
        end
        fitness[i] = objfun(population[i])
        debug && println("INIT $(i): $(population[i]) : $(fitness[i])")
    end
    offspring = Array{T}(undef, λ)
    fitoff = fill(Inf, λ)
    stgpop = fill(initStrategy, μ)
    stgoff = fill(initStrategy, λ)

    keep(interim, :fitness, copy(fitness), store)

    # Generation cycle
    itr = 0
    while true

        for i in 1:λ
            # Recombine the ρ selected parents to form a recombinant individual
            if ρ == 1
                j = rand(1:μ)
                recombinantStrategy = stgpop[j]
                recombinant = copy(population[j])
            else
                idx = randperm(μ)[1:ρ]
                recombinantStrategy = srecombination(stgpop[idx])
                recombinant = recombination(population[idx])
            end

            # Mutate the strategy parameter set of the recombinant
            stgoff[i] = smutation(recombinantStrategy)

            # Mutate the objective parameter set of the recombinant using the mutated strategy parameter set
            # to control the statistical properties of the object parameter mutation
            offspring[i] = mutation(recombinant, stgoff[i])

            # Evaluate fitness
            fitoff[i] = objfun(offspring[i])
        end

        # Select new parent population
        if selection == :plus
            idx = sortperm(vcat(fitness, fitoff))[1:μ]
            skip = idx[idx.<=μ]
            for i = 1:μ
                if idx[i] ∉ skip
                    ii = idx[i] - μ
                    population[i] = offspring[ii]
                    stgpop[i] = stgoff[ii]
                    fitness[i] = fitoff[ii]
                end
            end
        else
            idx = sortperm(fitoff)[1:μ]
            population = offspring[idx]
            stgpop = stgoff[idx]
            fitness = fitoff[idx]
        end
        keep(interim, :fitness, copy(fitness), store)
        keep(interim, :fitoff, copy(fitoff), store)

        # termination condition
        itr += 1
        if itr == iterations || termination(stgpop[1])
            break
        end
        verbose && println("BEST: $(fitness[1]): $(stgpop[1])")
    end

    return (
        bestIndividual=population[1],
        bestFitness=fitness[1],
        itr=itr,
        store=store
    )
end
