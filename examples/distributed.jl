module WireUp
    export wireup

    using Distributed
    using Sockets
    using PMI

    import Distributed: LPROC

    struct PMIManager <: Distributed.ClusterManager
        kvs::PMI.KVS
    end

    function start_worker(kvs, rank)
        Distributed.init_multi()
        close(stdin) # workers will not use it

        cookie = PMI.get(kvs, "cookie")

        init_worker(cookie)
        interface = IPv4(LPROC.bind_addr)
        if LPROC.bind_port == 0
            port_hint = 9000 + (getpid() % 1000)
            (port, sock) = listenany(interface, UInt16(port_hint))
            LPROC.bind_port = port
        else
            sock = listen(interface, LPROC.bind_port)
        end
        @async while isopen(sock)
            client = accept(sock)
            process_messages(client, client, true)
        end

        PMI.put!(kvs, string(rank), "$(LPROC.bind_port)#$(LPROC.bind_addr)")
        PMI.commit!(kvs)
        PMI.barrier()

        Sockets.nagle(sock, false)
        Sockets.quickack(sock, true)

        try
            # To prevent hanging processes on remote machines, newly launched workers exit if the
            # master process does not connect in time.
            Distributed.check_master_connect()
            while true; wait(); end
        catch err
            print(stderr, "unhandled exception on $(myid()): $(err)\nexiting.\n")
        end

        close(sock)
        PMI.finalize()
        exit(0)
    end

    function Distributed.launch(cm::PMIManager, params, launched, launch_ntfy)
        kvs = cm.kvs
        for wid in 1:(PMI.get_size()-1) # for all workers
            port, addr = split(PMI.get(kvs, string(wid)), "#")
            wc = WorkerConfig()
            wc.io = nothing
            wc.host = addr
            wc.bind_addr = addr
            wc.port = parse(Int, port)
            push!(launched, wc)
            notify(launch_ntfy)
        end
    end

    function Distributed.manage(::PMIManager, id, config, op)
    end

    function start_primary(kvs)
        PMI.barrier() # all workers have now written their port to the KVS, and are available for connection
        addprocs(PMIManager(kvs))
        atexit(PMI.finalize)
    end

    function wireup()
        PMI.init()
        rank = PMI.get_rank()
        kvs = PMI.KVS()
        if rank == 0
            PMI.put!(kvs, "cookie", cluster_cookie())
            PMI.commit!(kvs)
        end
        PMI.barrier()

        if rank == 0
            start_primary(kvs)
        else
            start_worker(kvs, rank)
        end
    end
end