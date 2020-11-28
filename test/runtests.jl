# Use `mpiexec` from MPICH_jll to get a PMI environment.
using MPICH_jll
using Test

nprocs_str = get(ENV, "JULIA_PMI_TEST_NPROCS","")
nprocs = nprocs_str == "" ? clamp(Sys.CPU_THREADS, 2, 4) : parse(Int, nprocs_str)

testdir = @__DIR__
istest(f) = endswith(f, ".jl") && startswith(f, "test_")
testfiles = sort(filter(istest, readdir(testdir)))

@info "Running PMI tests"

@testset "$f" for f in testfiles
    mpiexec() do cmd
        run(`$cmd -n $nprocs $(Base.julia_cmd()) $(joinpath(testdir, f))`)
        @test true
    end
end