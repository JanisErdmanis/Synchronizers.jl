using Synchronizers

ledger = ["hello", "world", "this", "is", "synchronizer"]

master = Synchronizer(server,ledger) # 

slaveledger = []
slave = Synchronizer(socket,slaveledger,:slave)


