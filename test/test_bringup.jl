using PMI

include(joinpath(dirname(pathof(PMI)), "..", "examples", "distributed.jl"))

# Everything before this is run on all processes
WireUp.wireup()

# Everything after this is only run on the primary

using Distributed
using Test

@test myid() == 1
@test length(procs()) == PMI.get_size()


