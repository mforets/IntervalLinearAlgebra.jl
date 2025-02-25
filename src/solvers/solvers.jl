abstract type LinearSolver end

struct GaussElimination <: LinearSolver end


struct HansenBliekRohn <: LinearSolver end

function (hbr::HansenBliekRohn)(A, b)
    n = length(b)
    compA = comparison_matrix(A)
    u = compA\mag.(b)
    d = diag(inv(compA))
    α = diag(compA) .- 1 ./d
    α = Interval.(-α, α) #TODO: probably directed rounded is needed here, need to check
    β = @. u/d - mag(b)
    β = Interval.(-β, β)
    x = (b .+ β)./(diag(A) .+ α)

end
function (ge::GaussElimination)(A, b)
    n = length(b)
    A = MMatrix{n, n}(A)
    b = MVector{n}(b)

end
## JACOBI
struct Jacobi <: LinearSolver
    max_iterations::Int
    atol::Float64
end

Jacobi() = Jacobi(20, 0.0)

function (jac::Jacobi)(x, A, b)

    n = length(b)
    @inbounds for _ in 1:jac.max_iterations
        xold = copy(x)
        @inbounds for i in 1:n
            x[i] = b[i]
            @inbounds for j in 1:n
                (i == j) || (x[i] -= A[i, j] * xold[j])
            end
            x[i] = (x[i]/A[i, i]) ∩ xold[i]
        end
        all(x .== xold) && break
        #all(isapprox.(x, xold; atol=atol)) && break
    end
    nothing
end

## GAUSS SEIDEL
struct GaussSeidel <: LinearSolver
    max_iterations::Int
    atol::Float64
end

GaussSeidel() = GaussSeidel(20, 0.0)

function (gs::GaussSeidel)(x, A, b)
    n = length(b)

    @inbounds for _ in 1:gs.max_iterations
        xold = copy(x)
        @inbounds for i in 1:n
            x[i] = b[i]
            @inbounds for j in 1:n
                (i == j) || (x[i] -= A[i, j] * x[j])
            end
            x[i] = (x[i]/A[i, i]) .∩ xold[i]
        end
        all(x .== xold) && break
        #all(isapprox.(x, xold; atol=atol)) && break
    end
    nothing
end

## KRAWCZYK
struct Krawczyk <: LinearSolver
    max_iterations::Int
    atol::Float64
end

Krawczyk() = Krawczyk(20, 0.0)

function (kra::Krawczyk)(x, A, b)
    Ac = mid.(A)
    for i = 1:kra.max_iterations
        xnew  = (Ac\b  - Ac\(A*x) + x) .∩ x
        all( x .== xnew ) && return x
        x = xnew
    end
    return x
end


## wrapper

function solve(A, b, method)

    A, b = precondition(A, b)
    x = enclose(A, b)

    method(x, A, b)

    return x
end

function solve(A, b, method::HansenBliekRohn)
    A, b = precondition(A, b)
    return method(A, b)
end
