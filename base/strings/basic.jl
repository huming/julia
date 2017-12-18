# This file is a part of Julia. License is MIT: https://julialang.org/license

"""
The `AbstractString` type is the supertype of all string implementations in
Julia. Strings are encodings of sequences of [Unicode](https://unicode.org/)
code points as represented by the `Char` type. Julia makes a few assumptions
about strings:

* Strings are encoded in terms of fixed-size "code units"
  * Code units can be extracted with `codeunit(s, i)`
  * The first code unit has index `1`
  * The last code unit has index `ncodeunits(s)`
  * Any index `i` such that `1 ≤ i ≤ ncodeunits(s)` is in bounds
* String indexing is done in terms of these code units:
  * Characters are extracted by `s[i]` with a valid string index `i`
  * Each `Char` in a string is encoded by one or more code units
  * Only the index of the first code unit of a `Char` is a valid index
  * The encoding of a `Char` is independent of what precedes or follows it
  * String encodings are [self-synchronizing] – i.e. `isvalid(s, i)` is O(1)

[self-synchronizing]: https://en.wikipedia.org/wiki/Self-synchronizing_code

Some string functions that extract code units, characters or substrings from
strings error if you pass them out-of-bounds or invalid string indices. This
includes `codeunit(s, i)`, `s[i]`, and `next(s, i)`. Functions that do string
index arithmetic take a more relaxed approach to indexing and give you the
closest valid string index when in-bounds, or when out-of-bounds, behave as if
there were an infinite number of characters padding each side of the string.
Usually these imaginary padding characters have code unit length `1` but string
types may choose different "imaginary" character sizes as makes sense for their
implementations (e.g. substrings may pass index arithmetic through to the
underlying string they provide a view into). Relaxed indexing functions include
those intended for index arithmetic: `thisind`, `nextind` and `prevind`. This
model allows index arithmetic to work with out-of- bounds indices as
intermediate values so long as one never uses them to retrieve a character,
which often helps avoid needing to code around edge cases.

See also: [`codeunit`](@ref), [`ncodeunits`](@ref), [`thisind`](@ref),
[`nextind`](@ref), [`prevind`](@ref)
"""
AbstractString

## required string functions ##

"""
    ncodeunits(s::AbstractString) -> Int

Return the number of code units in a string. Indices that are in bounds to
access this string must satisfy `1 ≤ i ≤ ncodeunits(s)`. Not all such indices
are valid – they may not be the start of a character, but they will return a
code unit value when calling `codeunit(s,i)`.

See also: [`codeunit`](@ref), [`checkbounds`](@ref), [`sizeof`](@ref),
[`length`](@ref), [`endof`](@ref)
"""
ncodeunits(s::AbstractString)

"""
    codeunit(s::AbstractString) -> Type{<:Union{UInt8, UInt16, UInt32}}

Return the code unit type of the given string object. For ASCII, Latin-1, or
UTF-8 encoded strings, this would be `UInt8`; for UCS-2 and UTF-16 it would be
`UInt16`; for UTF-32 it would be `UInt32`. The unit code type need not be
limited to these three types, but it's hard to think of widely used string
encodings that don't use one of these units. `codeunit(s)` is the same as
`typeof(codeunit(s,1))` when `s` is a non-empty string.

See also: [`ncodeunits`](@ref)
"""
codeunit(s::AbstractString)

"""
    codeunit(s::AbstractString, i::Integer) -> Union{UInt8, UInt16, UInt32}

Return the code unit value in the string `s` at index `i`. Note that

    codeunit(s, i) :: codeunit(s)

I.e. the value returned by `codeunit(s, i)` is of the type returned by
`codeunit(s)`.

See also: [`ncodeunits`](@ref), [`checkbounds`](@ref)
"""
@propagate_inbounds codeunit(s::AbstractString, i::Integer) = typeof(i) === Int ?
    throw(MethodError(codeunit, Tuple{typeof(s),Int})) : codeunit(s, Int(i))

"""
    isvalid(s::AbstractString, i::Integer) -> Bool

Predicate indicating whether the given index is the start of the encoding of a
character in `s` or not. If `isvalid(s, i)` is true then `s[i]` will return the
character whose encoding starts at that index, if it's false, then `s[i]` will
raise an invalid index error or a bounds error depending on if `i` is in bounds.
In order for `isvalid(s, i)` to be an O(1) function, the encoding of `s` must be
[self-synchronizing](https://en.wikipedia.org/wiki/Self-synchronizing_code) this
is a basic assumption of Julia's generic string support.

See also: [`getindex`](@ref), [`next`](@ref), [`thisind`](@ref),
[`nextind`](@ref), [`prevind`](@ref), [`length`](@ref)

# Examples

```jldoctest
julia> str = "αβγdef";

julia> isvalid(str, 1)
true

julia> str[1]
'α': Unicode U+03b1 (category Ll: Letter, lowercase)

julia> isvalid(str, 2)
false

julia> str[2]
ERROR: StringIndexError: invalid character index
Stacktrace:
[...]
```
"""
@propagate_inbounds isvalid(s::AbstractString, i::Integer) = typeof(i) === Int ?
    throw(MethodError(isvalid, Tuple{typeof(s),Int})) : isvalid(s, Int(i))

"""
    next(s::AbstractString, i::Integer) -> Tuple{Char, Int}

Return a tuple of the character in `s` at index `i` with the index of the start
of the following character in `s`. This is the key method that allows strings to
be iterated, yielding a sequences of characters. If `i` is out of bounds in `s`
then a bounds error is raised. The `next` function, as part of the iteration
protocoal may assume that `i` is the start of a character in `s`.

See also: [`getindex`](@ref), [`start`](@ref), [`done`](@ref),
[`checkbounds`](@ref)
"""
@propagate_inbounds next(s::AbstractString, i::Integer) = typeof(i) === Int ?
    throw(MethodError(next, Tuple{typeof(s),Int})) : next(s, Int(i))

## basic generic definitions ##

start(s::AbstractString) = 1
done(s::AbstractString, i::Integer) = i > ncodeunits(s)
eltype(::Type{<:AbstractString}) = Char
sizeof(s::AbstractString) = ncodeunits(s) * sizeof(codeunit(s))
endof(s::AbstractString) = thisind(s, ncodeunits(s))

function getindex(s::AbstractString, i::Integer)
    @boundscheck checkbounds(s, i)
    @inbounds return isvalid(s, i) ? next(s, i)[1] : string_index_err(s, i)
end

getindex(s::AbstractString, i::Colon) = s
# TODO: handle other ranges with stride ±1 specially?
# TODO: add more @propagate_inbounds annotations?
getindex(s::AbstractString, r::UnitRange{<:Integer}) = SubString(s, r)
getindex(s::AbstractString, v::AbstractVector{<:Integer}) =
    sprint(io->(for i in v; write(io, s[i]) end), sizehint=length(v))
getindex(s::AbstractString, v::AbstractVector{Bool}) =
    throw(ArgumentError("logical indexing not supported for strings"))

function get(s::AbstractString, i::Integer, default)
# TODO: use ternary once @inbounds is expression-like
    if checkbounds(Bool, s, i)
        @inbounds return s[i]
    else
        return default
    end
end

## bounds checking ##

checkbounds(::Type{Bool}, s::AbstractString, i::Integer) =
    1 ≤ i ≤ ncodeunits(s)
checkbounds(::Type{Bool}, s::AbstractString, r::AbstractRange{<:Integer}) =
    isempty(r) || (1 ≤ minimum(r) && maximum(r) ≤ ncodeunits(s))
checkbounds(::Type{Bool}, s::AbstractString, I::AbstractArray{<:Real}) =
    all(i -> checkbounds(Bool, s, i), I)
checkbounds(::Type{Bool}, s::AbstractString, I::AbstractArray{<:Integer}) =
    all(i -> checkbounds(Bool, s, i), I)
checkbounds(s::AbstractString, I::Union{Integer,AbstractArray}) =
    checkbounds(Bool, s, I) ? nothing : throw(BoundsError(s, I))

## construction, conversion, promotion ##

string() = ""
string(s::AbstractString) = s

(::Type{Vector{UInt8}})(s::AbstractString) = Vector{UInt8}(String(s))
(::Type{Array{UInt8}})(s::AbstractString) = Vector{UInt8}(s)
(::Type{Vector{Char}})(s::AbstractString) = collect(s)

Symbol(s::AbstractString) = Symbol(String(s))

convert(::Type{T}, s::T) where {T<:AbstractString} = s
convert(::Type{T}, s::AbstractString) where {T<:AbstractString} = T(s)

promote_rule(::Type{<:AbstractString}, ::Type{<:AbstractString}) = String

## string & character concatenation ##

"""
    *(s::Union{AbstractString, Char}, t::Union{AbstractString, Char}...) -> AbstractString

Concatenate strings and/or characters, producing a [`String`](@ref). This is equivalent
to calling the [`string`](@ref) function on the arguments. Concatenation of built-in
string types always produces a value of type `String` but other string types may choose
to return a string of a different type as appropriate.

# Examples
```jldoctest
julia> "Hello " * "world"
"Hello world"

julia> 'j' * "ulia"
"julia"
```
"""
(*)(s1::Union{Char, AbstractString}, ss::Union{Char, AbstractString}...) = string(s1, ss...)

one(::Union{T,Type{T}}) where {T<:AbstractString} = convert(T, "")

## generic string comparison ##

"""
    cmp(a::AbstractString, b::AbstractString) -> Int

Compare two strings for equality. Return `0` if both strings have the same
length and the character at each index is the same in both strings. Return `-1`
if `a` is a substring of `b`, or if `a` comes before `b` in alphabetical order.
Return `1` if `b` is a substring of `a`, or if `b` comes before `a` in
alphabetical order (technically, lexicographical order by Unicode code points).

# Examples
```jldoctest
julia> cmp("abc", "abc")
0

julia> cmp("ab", "abc")
-1

julia> cmp("abc", "ab")
1

julia> cmp("ab", "ac")
-1

julia> cmp("ac", "ab")
1

julia> cmp("α", "a")
1

julia> cmp("b", "β")
-1
```
"""
function cmp(a::AbstractString, b::AbstractString)
    a === b && return 0
    i = start(a)
    j = start(b)
    while !done(a, i)
        done(b, j) && return 1
        c, i = next(a, i)
        d, j = next(b, j)
        c ≠ d && return ifelse(c < d, -1, 1)
    end
    return ifelse(done(b, j), 0, -1)
end

"""
    ==(a::AbstractString, b::AbstractString) -> Bool

Test whether two strings are equal character by character (technically, Unicode
code point by code point).

# Examples
```jldoctest
julia> "abc" == "abc"
true

julia> "abc" == "αβγ"
false
```
"""
==(a::AbstractString, b::AbstractString) = cmp(a, b) == 0

"""
    isless(a::AbstractString, b::AbstractString) -> Bool

Test whether string `a` comes before string `b` in alphabetical order
(technically, in lexicographical order by Unicode code points).

# Examples
```jldoctest
julia> isless("a", "b")
true

julia> isless("β", "α")
false

julia> isless("a", "a")
false
```
"""
isless(a::AbstractString, b::AbstractString) = cmp(a, b) < 0

# faster comparisons for symbols

cmp(a::Symbol, b::Symbol) = Int(sign(ccall(:strcmp, Int32, (Cstring, Cstring), a, b)))

isless(a::Symbol, b::Symbol) = cmp(a, b) < 0

## character index arithmetic ##

"""
    length(s::AbstractString) -> Int
    length(s::AbstractString, i::Integer, j::Integer) -> Int

The number of characters in string `s` from indices `i` through `j`. This is
computed as the number of code unit indices from `i` to `j` which are valid
character indices. Without only a single string argument, this computes the
number of characters in the entire string. With `i` and `j` arguments it
computes the number of indices between `i` and `j` inclusive that are valid
indices in the string `s`. In addition to in-bounds values, `i` may take the
out-of-bounds value `ncodeunits(s) + 1` and `j` may take the out-of-bounds
value `0`.

See also: [`isvalid`](@ref), [`ncodeunits`](@ref), [`endof`](@ref),
[`thisind`](@ref), [`nextind`](@ref), [`prevind`](@ref)

# Examples
```jldoctest
julia> length("jμΛIα")
5
```
"""
length(s::AbstractString) = @inbounds return length(s, 1, ncodeunits(s))

function length(s::AbstractString, i::Int, j::Int)
    @boundscheck begin
        0 < i ≤ ncodeunits(s)+1 || throw(BoundsError(s, i))
        0 ≤ j < ncodeunits(s)+1 || throw(BoundsError(s, j))
    end
    n = 0
    for k = i:j
        @inbounds n += isvalid(s, k)
    end
    return n
end

@propagate_inbounds length(s::AbstractString, i::Integer, j::Integer) =
    length(s, Int(i), Int(j))

"""
    thisind(s::AbstractString, i::Integer) -> Int

If `i` is in bounds in `s` return the index of the start of the character whose
encoding code unit `i` is part of. In other words, if `i` is the start of a
character, return `i`; if `i` is not the start of a character, rewind until the
start of a character and return that index. If `i` is out of bounds in `s`
return `i`.

# Examples
```jldoctest
julia> thisind("αβγdef", -5)
-5

julia> thisind("αβγdef", 1)
1

julia> thisind("αβγdef", 3)
3

julia> thisind("αβγdef", 4)
3

julia> thisind("αβγdef", 9)
9

julia> thisind("αβγdef", 10)
10

julia> thisind("αβγdef", 20)
20
"""
thisind(s::AbstractString, i::Integer) = thisind(s, Int(i))

function thisind(s::AbstractString, i::Int)
    z = ncodeunits(s) + 1
    i == z && return i
    @boundscheck 0 ≤ i ≤ z || throw(BoundsError(s, i))
    @inbounds while 1 < i && !isvalid(s, i)
        i -= 1
    end
    return i
end

"""
    prevind(str::AbstractString, i::Integer, n::Integer=1) -> Int

If `i` is in bounds in `s` return the index of the start of the character whose
encoding starts before index `i`. In other words, if `i` is the start of a
character, return the start of the previous character; if `i` is not the start
of a character, rewind until the start of a character and return that index.
If `i` is out of bounds in `s` return `i - 1`. If `n == 0` return `i`.

# Examples
```jldoctest
julia> prevind("αβγdef", 3)
1

julia> prevind("αβγdef", 1)
0

julia> prevind("αβγdef", 0)
-1

julia> prevind("αβγdef", 3, 2)
0
```
"""
prevind(s::AbstractString, i::Integer, n::Integer) = prevind(s, Int(i), Int(n))
prevind(s::AbstractString, i::Integer)             = prevind(s, Int(i))
prevind(s::AbstractString, i::Int)                 = prevind(s, i, 1)

function prevind(s::AbstractString, i::Int, n::Int)
    n < 0 && throw(ArgumentError("n cannot be negative: $n"))
    z = ncodeunits(s) + 1
    @boundscheck 0 < i ≤ z || throw(BoundsError(s, i))
    n == 0 && return thisind(s, i) == i ? i : string_index_err(s, i)
    while n > 0 && 1 < i
        @inbounds n -= isvalid(s, i -= 1)
    end
    return i - n
end

"""
    nextind(str::AbstractString, i::Integer, n::Integer=1) -> Int

If `i` is in bounds in `s` return the index of the start of the character whose
encoding starts after index `i`. If `i` is out of bounds in `s` return `i + 1`.
If `n == 0` return `i`.

# Examples
```jldoctest
julia> str = "αβγdef";

julia> nextind(str, 1)
3

julia> nextind(str, 1, 2)
5

julia> endof(str)
9

julia> nextind(str, 9)
10
```
"""
nextind(s::AbstractString, i::Integer, n::Integer) = nextind(s, Int(i), Int(n))
nextind(s::AbstractString, i::Integer)             = nextind(s, Int(i))
nextind(s::AbstractString, i::Int)                 = nextind(s, i, 1)

function nextind(s::AbstractString, i::Int, n::Int)
    n < 0 && throw(ArgumentError("n cannot be negative: $n"))
    z = ncodeunits(s)
    @boundscheck 0 ≤ i ≤ z || throw(BoundsError(s, i))
    n == 0 && return thisind(s, i) == i ? i : string_index_err(s, i)
    while n > 0 && i < z
        @inbounds n -= isvalid(s, i += 1)
    end
    return i + n
end

## string index iteration type ##

struct EachStringIndex{T<:AbstractString}
    s::T
end
keys(s::AbstractString) = EachStringIndex(s)

length(e::EachStringIndex) = length(e.s)
start(e::EachStringIndex) = start(e.s)
next(e::EachStringIndex, state) = (state, nextind(e.s, state))
done(e::EachStringIndex, state) = done(e.s, state)
eltype(::Type{EachStringIndex}) = Int

"""
    isascii(c::Union{Char,AbstractString}) -> Bool

Test whether a character belongs to the ASCII character set, or whether this is true for
all elements of a string.

# Examples
```jldoctest
julia> isascii('a')
true

julia> isascii('α')
false

julia> isascii("abc")
true

julia> isascii("αβγ")
false
```
"""
isascii(c::Char) = bswap(reinterpret(UInt32, c)) < 0x80
isascii(s::AbstractString) = all(isascii, s)

## string map, filter, has ##

function map(f, s::AbstractString)
    out = IOBuffer(StringVector(endof(s)), true, true)
    truncate(out, 0)
    for c in s
        c′ = f(c)
        isa(c′, Char) || throw(ArgumentError(
            "map(f, s::AbstractString) requires f to return Char; " *
            "try map(f, collect(s)) or a comprehension instead"))
        write(out, c′::Char)
    end
    String(take!(out))
end

function filter(f, s::AbstractString)
    out = IOBuffer(StringVector(endof(s)), true, true)
    truncate(out, 0)
    for c in s
        f(c) && write(out, c)
    end
    String(take!(out))
end

## string first and last ##

"""
    first(s::AbstractString, n::Integer)

Get a string consisting of the first `n` characters of `s`.

```jldoctest
julia> first("∀ϵ≠0: ϵ²>0", 0)
""

julia> first("∀ϵ≠0: ϵ²>0", 1)
"∀"

julia> first("∀ϵ≠0: ϵ²>0", 3)
"∀ϵ≠"
```
"""
first(s::AbstractString, n::Integer) = s[1:min(end, nextind(s, 0, n))]

"""
    last(s::AbstractString, n::Integer)

Get a string consisting of the last `n` characters of `s`.

```jldoctest
julia> last("∀ϵ≠0: ϵ²>0", 0)
""

julia> last("∀ϵ≠0: ϵ²>0", 1)
"0"

julia> last("∀ϵ≠0: ϵ²>0", 3)
"²>0"
```
"""
last(s::AbstractString, n::Integer) = s[max(1, prevind(s, ncodeunits(s)+1, n)):end]

"""
    reverseind(v, i)

Given an index `i` in [`reverse(v)`](@ref), return the corresponding index in
`v` so that `v[reverseind(v,i)] == reverse(v)[i]`. (This can be nontrivial in
cases where `v` contains non-ASCII characters.)

# Examples
```jldoctest
julia> r = reverse("Julia")
"ailuJ"

julia> for i in 1:length(r)
           print(r[reverseind("Julia", i)])
       end
Julia
```
"""
reverseind(s::AbstractString, i::Integer) = thisind(s, ncodeunits(s)-i+1)

"""
    repeat(s::AbstractString, r::Integer)

Repeat a string `r` times. This can be written as `s^r`.

See also: [`^`](@ref)

# Examples
```jldoctest
julia> repeat("ha", 3)
"hahaha"
```
"""
repeat(s::AbstractString, r::Integer) = repeat(convert(String, s), r)

"""
    ^(s::Union{AbstractString,Char}, n::Integer)

Repeat a string or character `n` times. This can also be written as `repeat(s, n)`.

See also: [`repeat`](@ref)

# Examples
```jldoctest
julia> "Test "^3
"Test Test Test "
```
"""
(^)(s::Union{AbstractString,Char}, r::Integer) = repeat(s, r)

# reverse-order iteration for strings and indices thereof
start(r::Iterators.Reverse{<:AbstractString}) = endof(r.itr)
done(r::Iterators.Reverse{<:AbstractString}, i) = i < start(r.itr)
next(r::Iterators.Reverse{<:AbstractString}, i) = (r.itr[i], prevind(r.itr, i))
start(r::Iterators.Reverse{<:EachStringIndex}) = endof(r.itr.s)
done(r::Iterators.Reverse{<:EachStringIndex}, i) = i < start(r.itr.s)
next(r::Iterators.Reverse{<:EachStringIndex}, i) = (i, prevind(r.itr.s, i))