# implementing scale-free Hilbert ordering. Real all about it here:
# http://doc.cgal.org/latest/Spatial_sorting/index.html

# original implementation in:
# https://github.com/JuliaGeometry/GeometricalPredicates.jl
# The GeometricalPredicates.jl package is licensed under the MIT "Expat" License:
#    Copyright (c) 2014: Ariel Keselman.

# modifications for StaticArrays: sjkelly

abstract type AbstractCoordinate end
mutable struct CoordinateX <: AbstractCoordinate end
mutable struct CoordinateY <: AbstractCoordinate end
mutable struct CoordinateZ <: AbstractCoordinate end
const coordinatex = CoordinateX()
const coordinatey = CoordinateY()
const coordinatez = CoordinateZ()
next2d(::CoordinateX) = coordinatey
next2d(::CoordinateY) = coordinatex
next3d(::CoordinateX) = coordinatey
next3d(::CoordinateY) = coordinatez
next3d(::CoordinateZ) = coordinatex
nextnext3d(::CoordinateX) = coordinatez
nextnext3d(::CoordinateY) = coordinatex
nextnext3d(::CoordinateZ) = coordinatey

abstract type AbstractDirection end
mutable struct Forward <: AbstractDirection end
mutable struct Backward <: AbstractDirection end
const forward = Forward()
const backward = Backward()
Base.:!(::Forward) = backward
Base.:!(::Backward) = forward

compare(::Forward, ::CoordinateX, p1::AbstractPoint, p2::AbstractPoint) = getx(p1) < getx(p2)
compare(::Backward, ::CoordinateX, p1::AbstractPoint, p2::AbstractPoint) = getx(p1) > getx(p2)
compare(::Forward, ::CoordinateY, p1::AbstractPoint, p2::AbstractPoint) = gety(p1) < gety(p2)
compare(::Backward, ::CoordinateY, p1::AbstractPoint, p2::AbstractPoint) = gety(p1) > gety(p2)
compare(::Forward, ::CoordinateZ, p1::AbstractPoint, p2::AbstractPoint) = getz(p1) < getz(p2)
compare(::Backward, ::CoordinateZ, p1::AbstractPoint, p2::AbstractPoint) = getz(p1) > getz(p2)

function select!(direction::AbstractDirection, coordinate::AbstractCoordinate, v::Array{T,1}, k::Int, lo::Int, hi::Int) where T<:AbstractPoint
    lo <= k <= hi || error("select index $k is out of range $lo:$hi")
    @inbounds while lo < hi
        if hi-lo == 1
            if compare(direction, coordinate, v[hi], v[lo])
                v[lo], v[hi] = v[hi], v[lo]
            end
            return v[k]
        end
        pivot = v[(lo+hi)>>>1]
        i, j = lo, hi
        while true
            while compare(direction, coordinate, v[i], pivot); i += 1; end
            while compare(direction, coordinate, pivot, v[j]); j -= 1; end
            i <= j || break
            v[i], v[j] = v[j], v[i]
            i += 1; j -= 1
        end
        if k <= j
            hi = j
        elseif i <= k
            lo = i
        else
            return pivot
        end
    end
    return v[lo]
end

function hilbertsort!(directionx::AbstractDirection, directiony::AbstractDirection, coordinate::AbstractCoordinate, a::Array{T,1}, lo::Int64, hi::Int64, lim::Int64=4) where T<:AbstractPoint2D
    hi-lo <= lim && return a

    i2 = (lo+hi)>>>1
    i1 = (lo+i2)>>>1
    i3 = (i2+hi)>>>1

    select!(directionx, coordinate, a, i2, lo, hi)
    select!(directiony, next2d(coordinate), a, i1, lo, i2)
    select!(!directiony, next2d(coordinate), a, i3, i2, hi)

    hilbertsort!(directiony, directionx, next2d(coordinate), a, lo, i1, lim)
    hilbertsort!(directionx, directiony, coordinate, a, i1, i2, lim)
    hilbertsort!(directionx, directiony, coordinate, a, i2, i3, lim)
    hilbertsort!(!directiony, !directionx, next2d(coordinate), a, i3, hi, lim)

    return a
end

function hilbertsort!(directionx::AbstractDirection, directiony::AbstractDirection, directionz::AbstractDirection, coordinate::AbstractCoordinate, a::Array{T,1}, lo::Int64, hi::Int64, lim::Int64=8) where T<:AbstractPoint3D
    hi-lo <= lim && return a

    i4 = (lo+hi)>>>1
    i2 = (lo+i4)>>>1
    i1 = (lo+i2)>>>1
    i3 = (i2+i4)>>>1
    i6 = (i4+hi)>>>1
    i5 = (i4+i6)>>>1
    i7 = (i6+hi)>>>1

    select!(directionx, coordinate, a, i4, lo, hi)
    select!(directiony, next3d(coordinate), a, i2, lo, i4)
    select!(directionz, nextnext3d(coordinate), a, i1, lo, i2)
    select!(!directionz, nextnext3d(coordinate), a, i3, i2, i4)
    select!(!directiony, next3d(coordinate), a, i6, i4, hi)
    select!(directionz, nextnext3d(coordinate), a, i5, i4, i6)
    select!(!directionz, nextnext3d(coordinate), a, i7, i6, hi)

    hilbertsort!( directionz,  directionx,  directiony, nextnext3d(coordinate), a, lo, i1, lim)
    hilbertsort!( directiony,  directionz,  directionx, next3d(coordinate),     a, i1, i2, lim)
    hilbertsort!( directiony,  directionz,  directionx, next3d(coordinate),     a, i2, i3, lim)
    hilbertsort!( directionx, !directiony, !directionz, coordinate,             a, i3, i4, lim)
    hilbertsort!( directionx, !directiony, !directionz, coordinate,             a, i4, i5, lim)
    hilbertsort!(!directiony,  directionz, !directionx, next3d(coordinate),     a, i5, i6, lim)
    hilbertsort!(!directiony,  directionz, !directionx, next3d(coordinate),     a, i6, i7, lim)
    hilbertsort!(!directionz, !directionx,  directiony, nextnext3d(coordinate), a, i7, hi, lim)

    return a
end

hilbertsort!(a::Array{T,1}) where {T<:AbstractPoint2D} = hilbertsort!(backward, backward, coordinatey, a, 1, length(a))
hilbertsort!(a::Array{T,1}, lo::Int64, hi::Int64, lim::Int64) where {T<:AbstractPoint2D} = hilbertsort!(backward, backward, coordinatey, a, lo, hi, lim)
hilbertsort!(a::Array{T,1}) where {T<:AbstractPoint3D} = hilbertsort!(backward, backward, backward, coordinatez, a, 1, length(a))
hilbertsort!(a::Array{T,1}, lo::Int64, hi::Int64, lim::Int64) where {T<:AbstractPoint3D} = hilbertsort!(backward, backward, backward, coordinatey, a, lo, hi, lim)