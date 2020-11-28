using PMI
using Test

@test PMI.initialized() == false

PMI.init()

@test PMI.initialized()

nranks = PMI.get_size()
rank = PMI.get_rank()

@test nranks >= 1
@test 0 <= rank < nranks

PMI.barrier()

@test PMI.get_clique_size() >= 1
@test rank ∈ PMI.get_clique_ranks()

PMI.finalize()