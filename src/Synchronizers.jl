module Synchronizers

using Sockets

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

stack(io::IO,n::Int) = stack(io,UInt8[reinterpret(UInt8,Int[n])...])
unstack(io::IO,x::Type{Int}) = reinterpret(Int,unstack(io))[1]


struct Record
    fname::AbstractString
    data::Vector{UInt8}
end

import Base.==
==(a::Record,b::Record) = a.fname==b.fname && a.data==b.data


function stack(socket::IO,record::Record)
    binary = UInt8[record.fname...,UInt8('\n'),record.data...]
    stack(socket,binary)
end

function unstack(socket::IO,x::Type{Record})
    binary = unstack(socket)
    n = findfirst(x->x==UInt8('\n'),binary)
    fname = String(binary[1:n-1])
    data = binary[n+1:end]
    return Record(fname,data)
end

### I could test whether the stuff works for the buffer.

mutable struct Ledger
    dir::AbstractString
    records::Vector{Record}
end

==(a::Ledger,b::Ledger) = a.records==b.records

import Base.length
length(ledger::Ledger) = length(ledger.records)

function readfile(fname::AbstractString)
    file = open(fname,"r") 
    data = UInt8[]
    while !eof(file)
        push!(data,read(file,UInt8))
    end
    close(file)
    return data
end

function Ledger(rootdir::AbstractString)
    mkpath(rootdir)
    records = Record[]
    time = []

    ### I actually need to sort them by date 
    for (dir, _, files) in walkdir(rootdir)
        for fname in files
            fullpath = "$dir/$fname"
            data = readfile(fullpath)
            record = Record(relpath(fullpath,rootdir),data)
            push!(records,record)
            push!(time,ctime(fullpath))
        end
    end
    
    if length(records)>1
        sp = sortperm(time)
        records = records[sp]
    end

    return Ledger(rootdir,records)
end

### One can latter extend this method to specify what to do with a specific type
import Base.push!
function push!(l::Ledger,r::Record)
    push!(l.records,r)
    mkpath(dirname(l.dir * r.fname))
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
                m = unstack(socket,Int)
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
