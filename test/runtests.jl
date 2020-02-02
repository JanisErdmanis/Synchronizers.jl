using Synchronizers
using Synchronizers: stack, unstack, Record, Ledger, serve, isready,  Synchronizer, sync
using Test

### Testing Int

io = IOBuffer()
stack(io,123)

ionew = IOBuffer(take!(io))
@test unstack(ionew,Int)==123

### Testing Record

record = Record("hello",b"world")

io = IOBuffer()
stack(io,record)

ionew = IOBuffer(take!(io))
@test unstack(ionew,Record)==record

### Testing now the ledger
masterdir = dirname(@__FILE__) * "/master/"

mledger = Ledger(masterdir)
push!(mledger,Record("hellohere",b"world"))

# ### Now let's test synchronization

task = @async serve(2000,mledger)

sleep(1)

slavedir = dirname(@__FILE__) * "/slave/"
sledger = Ledger(slavedir)

s = Synchronizer(2000,sledger)

@test isready(s)==true

sync(s)

@test mledger==sledger

# WIP IO is too fast
#sledger2 = Ledger(sledger)
#@test sledger==sledger2
