module Synchronizers

function stack(io::IO,msg::Vector{UInt8})
    frontbytes = reinterpret(UInt8,Int16[length(msg)])
    item = UInt8[frontbytes...,msg...]
    write(io,item)
end

function unstack(io::IO)
    sizebytes = [read(io,UInt8),read(io,UInt8)]
    size = reinterpret(Int16,sizebytes)[1]
    
    msg = UInt8[]
    for i in 1:size
        push!(msg,read(io,UInt8))
    end
    return msg
end

stack(io::IO,n::Int) = stack(io,reinterpret(UInt8,Int[n]))
unstack(io::IO,x::Type{Int}) = reinterepret(Int,unstack(io))[1]


struct Record
    fname::AbstractString
    data::Vector{UInt8}
end

function stack(socket::IO,record::Record)
    binary = UInt8[record.fname...,'\n',record.data...]
    stack(socket,binary)
end

function unstack(socket::IO,x::Type{Record})
    binary = unstack(socket)
    n = findfirst(x->x=='\n',binary)
    fname = String(binary[1:n-1])
    data = binary[n+1:end]
    return Record(fname,data)
end

### I could test whether the stuff works for the buffer.


mutable struct Ledger
    dir::AbstractString
    records::Vector{Record}
end

import Base.length
length(ledger::Ledger) = length(ledger.records)

function Ledger(dir::AbstractString)
    records = Record[]

    ### I actually need to sort them by date
    for fname in readdir(dir)
        data = readall(fname)
        record = Record(fname,data)
        push!(records,record)
    end

    return Ledger(dir,records)
end

### One can latter extend this method to specify what to do with a specific type
import Base.push!
function push!(l::Ledger,r::Record)
    push!(l.items,r)
    write(l.dir * r.fname,r.data)
end

# Now the question is how to send and receive the record


function serve(port,ledger::Ledger)
    server = listen(port)
    while true
        socket = accept(server)
        @async begin
            n = length(ledger)::Int
            stack(socket,n)

            while true
                m = parse(Int,unstack(socket))
                if m==0
                    n = length(ledger)::Int
                    stack(socket,n)
                else
                    stack(socket,ledger.records[m])
                end
            end            
        end
    end
end

# If I make a daemon, how should I name this?
struct Synchronizer
    socket
    n ### The global state
    ledger::Ledger
end

function Synchronizer(port,ledger::Ledger)
    socket = connect(port)
    n = unstack(socket,Int)
    return Synchronizer(socket,n,ledger)
end

import Base.isready
function isready(s::Synchronizer)
    if length(s.ledger)<s.n
        return true
    else
        stack(s.socket,0)
        n = unstack(s.socket,Int) ### Perhaps I could have unstack with a Datatype!!!
        if n>s.n
            s.n = n
            return true
        else
            return false
        end
    end
end

function sync(s::Synchronizer)
    while isready(s)
        m  = length(s.ledger) + 1
        stack(s.socket,m)
        record = unstack(s.socket,Record)
        push!(s.ledger,record)
    end
end


end # module
