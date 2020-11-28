using PMI
using Test

PMI.init()

nranks = PMI.get_size()
rank = PMI.get_rank()

kvs = PMI.KVS()
if rank == 0
    PMI.put!(kvs, "primary", string(rank))
    PMI.commit!(kvs)
end
PMI.barrier()

@test PMI.get(kvs, "primary") == "0"

PMI.finalize()