module PMI

using Libdl
include("util.jl")

const __libpmi = Ref{String}("libpmi.so")
function __init__()
    if haskey(ENV, "PMI_LIBRARY")
        __libpmi[] = ENV["PMI_LIBRARY"]
    end
end

const PMI_SUCCESS = Cint(0) # operation completed successfully
#    PMI_FAIL (-1): operation failed
#    PMI_ERR_INIT (1): PMI not initialized
#    PMI_ERR_NOMEM (2): input buffer not large enough
#    PMI_ERR_INVALID_ARG (3): invalid argument
#    PMI_ERR_INVALID_KEY (4): invalid key argument
#    PMI_ERR_INVALID_KEY_LENGTH (5): invalid key length argument
#    PMI_ERR_INVALID_VAL (6): invalid val argument
#    PMI_ERR_INVALID_VAL_LENGTH (7): invalid val length argument
#    PMI_ERR_INVALID_LENGTH (8): invalid length argument
#    PMI_ERR_INVALID_NUM_ARGS (9): invalid number of arguments
#    PMI_ERR_INVALID_ARGS (10): invalid args argument
#    PMI_ERR_INVALID_NUM_PARSED (11): invalid num_parsed length argument
#    PMI_ERR_INVALID_KEYVALP (12): invalid keyvalp argument
#    PMI_ERR_INVALID_SIZE (13): invalid size argument

struct PMIError
    code::Cint
end
macro check(ex)
    quote
        res = $(esc(ex))
        if res != PMI_SUCCESS 
            throw(PMIError(res))
        end
    end
end

"""
    init()

Initialize the PMI library for this process. Upon success, the return value
will be `true` if this process was created by `PMI_Spawn_multiple()``,
or `false` if not.
"""
function init()
    res = Ref{Cint}()
    @check @runtime_ccall((:PMI_Init, __libpmi[]), Cint, (Ptr{Cint},), res)
    res[] == 1
end

"""
    initialized()

Check if the PMI library has been initialized for this process.
"""
function initialized()
    res = Ref{Cint}()
    @check @runtime_ccall((:PMI_Initialized, __libpmi[]), Cint, (Ptr{Cint},), res)
    res[] == 1
end

"""
    finalize()

Finalize the PMI library for this process.
"""
function finalize()
    @check @runtime_ccall((:PMI_Finalize, __libpmi[]), Cint, ())
end

"""
    abort(exit_code, error_msg)

Abort the process group associated with this process.
"""
function abort(exit_code, error_msg)
    @check @runtime_ccall((:PMI_Abort, __libpmi[]), Cint, (Cint, Cstring), exit_code, error_msg)
end

"""
    get_size()

Obtain the size of the process group to which the local process belongs. 
"""
function get_size()
    res = Ref{Cint}()
    @check @runtime_ccall((:PMI_Get_size, __libpmi[]), Cint, (Ptr{Cint},), res)
    res[]
end

"""
    get_rank()

Obtain the rank (0…​size-1) of the local process in the process group. 
"""
function get_rank()
    res = Ref{Cint}()
    @check @runtime_ccall((:PMI_Get_rank, __libpmi[]), Cint, (Ptr{Cint},), res)
    res[]
end

"""
    get_clique_size()

Obtain the number of processes on the local node.
"""
function get_clique_size()
    res = Ref{Cint}()
    @check @runtime_ccall((:PMI_Get_clique_size, __libpmi[]), Cint, (Ptr{Cint},), res)
    res[]
end

"""
    get_clique_ranks()

Get the ranks of the local processes in the process group. This is a simple 
topology function to distinguish between processes that can communicate through
IPC mechanisms (e.g., shared memory) and other network mechanisms. 
"""
function get_clique_ranks()
    size = get_clique_size()
    ranks = Array{Cint,1}(undef, size)
    @check @runtime_ccall((:PMI_Get_clique_ranks, __libpmi[]), Cint, (Ptr{Cint}, Cint), ranks, size)
    return ranks
end

"""
    barrier()

This function is a collective call across all processes in the process group 
the local process belongs to.
"""
function barrier()
    @check @runtime_ccall((:PMI_Barrier, __libpmi[]), Cint, ())
end

# int PMI_Get_id_length_max (int *length);
function get_name_length_max()
    res = Ref{Cint}()
    @check @runtime_ccall((:PMI_KVS_Get_name_length_max, __libpmi[]), Cint, (Ptr{Cint},), res)
    res[]
end

function get_key_length_max()
    res = Ref{Cint}()
    @check @runtime_ccall((:PMI_KVS_Get_key_length_max, __libpmi[]), Cint, (Ptr{Cint},), res)
    res[]
end

function get_value_length_max()
    res = Ref{Cint}()
    @check @runtime_ccall((:PMI_KVS_Get_value_length_max, __libpmi[]), Cint, (Ptr{Cint},), res)
    res[]
end

function get_my_name()
    length = get_name_length_max()
    data = Array{UInt8, 1}(undef, length)
    @check @runtime_ccall((:PMI_KVS_Get_my_name, __libpmi[]), Cint, (Ptr{Cchar}, Cint), data, length)
    return unsafe_string(pointer(data))
end
struct KVS
    name::String
    function KVS()
        new(get_my_name())
    end
end

function put!(kvs::KVS, key, value)
    @assert length(key) <= get_key_length_max()
    @assert length(value) <= get_value_length_max()

    @check @runtime_ccall((:PMI_KVS_Put, __libpmi[]), Cint, (Cstring, Cstring, Cstring), kvs.name, key, value)
end

function get(kvs::KVS, key)
    @assert length(key) <= get_key_length_max()
    len = get_value_length_max()
    data = Array{UInt8, 1}(undef, len)
    @check @runtime_ccall((:PMI_KVS_Get, __libpmi[]), Cint, (Cstring, Cstring, Ptr{Cchar}, Cint), kvs.name, key, data, len)
    return unsafe_string(pointer(data))
end

function commit!(kvs::KVS)
    @check @runtime_ccall((:PMI_KVS_Commit, __libpmi[]), Cint, (Cstring,), kvs.name)
end

# int PMI_KVS_Create( char kvsname[], int length );
# int PMI_KVS_Destroy( const char kvsname[] );
# int PMI_KVS_Iter_first(const char kvsname[], char key[], int key_len, char val[], int val_len);
# int PMI_KVS_Iter_next(const char kvsname[], char key[], int key_len, char val[], int val_len);
# int PMI_Get_universe_size (int *size);
# int PMI_Get_appnum (int *appnum);

end # module
