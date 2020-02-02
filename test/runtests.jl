using Synchronizers

ledger = ["hello", "world", "this", "is", "synchronizer"]

master = Synchronizer(server,ledger) # 

slaveledger = []
slave = Synchronizer(socket,slaveledger,:slave)


function serve(port,ledger)
    server = listen(port)
    while true
        socket = accept(server)
        @async begin
            n = length(ledger)
            write(socket,"$n")
            
        end
    end
    
end
