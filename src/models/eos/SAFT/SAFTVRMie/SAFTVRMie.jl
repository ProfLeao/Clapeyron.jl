struct SAFTVRMieParam <: EoSParam
    segment::SingleParam{Float64}
    sigma::PairParam{Float64}
    lambda_a::PairParam{Float64}
    lambda_r::PairParam{Float64}
    epsilon::PairParam{Float64}
    epsilon_assoc::AssocParam{Float64}
    bondvol::AssocParam{Float64}
    Mw::SingleParam{Float64}
end

abstract type SAFTVRMieModel <: SAFTModel end
@newmodel SAFTVRMie SAFTVRMieModel SAFTVRMieParam

export SAFTVRMie
function SAFTVRMie(components; idealmodel=BasicIdeal, userlocations=String[], ideal_userlocations=String[], verbose=false)
    params,sites = getparams(components, ["SAFT/SAFTVRMie", "properties/molarmass.csv"]; userlocations=userlocations, verbose=verbose)

    params["Mw"].values .*= 1E-3
    Mw = params["Mw"]
    segment = params["m"]
    params["sigma"].values .*= 1E-10
    sigma = sigma_LorentzBerthelot(params["sigma"])
    epsilon = epsilon_HudsenMcCoubrey(params["epsilon"], sigma)
    lambda_a = lambda_LorentzBerthelot(params["lambda_a"])
    lambda_r = lambda_LorentzBerthelot(params["lambda_r"])
    epsilon_assoc = params["epsilon_assoc"]
    bondvol = params["bondvol"]

    packagedparams = SAFTVRMieParam(segment, sigma, lambda_a, lambda_r, epsilon, epsilon_assoc, bondvol, Mw)
    references = ["10.1063/1.4819786", "10.1080/00268976.2015.1029027"]

    model = SAFTVRMie(packagedparams, sites, idealmodel; ideal_userlocations=ideal_userlocations, references=references, verbose=verbose)
    return model
end

function a_res(model::SAFTVRMieModel, V, T, z)
    return @f(a_mono) + @f(a_chain) + @f(a_assoc)
end

function a_mono(model::SAFTVRMieModel, V, T, z)
    return @f(a_hs)+@f(a_disp)
end
function a_disp(model::SAFTVRMieModel, V, T, z)
    return @f(a_1)+@f(a_2)+@f(a_3)
end

function a_hs(model::SAFTVRMieModel, V, T, z)
    ζ0 = @f(ζn, 0)
    ζ1 = @f(ζn, 1)
    ζ2 = @f(ζn, 2)
    ζ3 = @f(ζn, 3)
    N = N_A*∑(z)
    return 6*V/π/N*(3ζ1*ζ2/(1-ζ3) + ζ2^3/(ζ3*(1-ζ3)^2) + (ζ2^3/ζ3^2-ζ0)*log(1-ζ3))
end

function ζn(model::SAFTVRMieModel, V, T, z, n)
    return π/6*@f(ρ_S) * ∑(@f(x_S,i)*@f(d,i)^n for i ∈ @comps)
end

function ρ_S(model::SAFTVRMieModel, V, T, z)
    N = N_A #* sum(z)
    m = model.params.segment.values
    m̄ =dot(z,m) #/ sum(z)
    return (N/V) * m̄
end

function x_S(model::SAFTVRMieModel, V, T, z, i)
    m = model.params.segment.values
    m̄ =dot(z,m)
    return z[i]*m[i]/m̄
end

function d(model::SAFTVRMieModel, V, T, z, i)
    ϵ = model.params.epsilon.diagvalues[i]
    σ = model.params.sigma.diagvalues[i]
    λr = model.params.lambda_r.diagvalues[i]
    λa = model.params.lambda_a.diagvalues[i]
    u = SAFTVRMieconsts.u
    w = SAFTVRMieconsts.w
    θ = @f(C,λa,λr)*ϵ/T
    return σ*(1-∑(w[j]*(θ/(θ+u[j]))^(1/λr)*(exp(θ*(1/(θ/(θ+u[j]))^(λa/λr)-1))/(u[j]+θ)/λr) for j ∈ 1:5))
end

function d(model::SAFTVRMieModel, V, T, z, i, j)
    return (@f(d,i)+@f(d,j))/2
end


function C(model::SAFTVRMieModel, V, T, z, λa, λr)
    return (λr/(λr-λa)) * (λr/λa)^(λa/(λr-λa))
end

function ζ_X(model::SAFTVRMieModel, V, T, z)
    comps = @comps
    return π/6*@f(ρ_S)*∑(@f(x_S,i)*@f(x_S,j)*(@f(d,i)+@f(d,j))^3/8 for i ∈ comps for j ∈ comps)
end

function a_1(model::SAFTVRMieModel, V, T, z)
    comps = @comps
    m = model.params.segment.values
    m̄ =dot(z,m)/sum(z)
    return m̄/T * ∑(@f(x_S,i)*@f(x_S,j)*@f(a_1,i,j) for i ∈ comps for j ∈ comps)
end

function a_1(model::SAFTVRMieModel, V, T, z, i, j)
    ϵ = model.params.epsilon.values[i,j]
    λr = model.params.lambda_r.values[i,j]
    λa = model.params.lambda_a.values[i,j]
    x_0ij = @f(x_0,i,j)
    C = @f(C,λa,λr)
    return 2*π*ϵ*@f(d,i,j)^3*C*@f(ρ_S) *
        ( x_0ij^λa*(@f(aS_1,λa)+@f(B,λa,x_0ij)) -
            x_0ij^λr*(@f(aS_1,λr)+@f(B,λr,x_0ij)) )
end

function aS_1(model::SAFTVRMieModel, V, T, z, λ)
    ζeff_ = @f(ζeff,λ)
    return -1/(λ-3)*(1-ζeff_/2)/(1-ζeff_)^3
end

function ζeff(model::SAFTVRMieModel, V, T, z, λ)
    A = SAFTγMieconsts.A
    ζₓ = @f(ζ_X)
    return A * SA[1; 1/λ; 1/λ^2; 1/λ^3] ⋅ SA[ζₓ; ζₓ^2; ζₓ^3; ζₓ^4]
end

function B(model::SAFTVRMieModel, V, T, z, λ, x_0)
    I = (1-x_0^(3-λ))/(λ-3)
    J = (1-(λ-3)*x_0^(4-λ)+(λ-4)*x_0^(3-λ))/((λ-3)*(λ-4))
    ζₓ = @f(ζ_X)
    return I*(1-ζₓ/2)/(1-ζₓ)^3-9*J*ζₓ*(ζₓ+1)/(2*(1-ζₓ)^3)
end

function x_0(model::SAFTVRMieModel, V, T, z, i, j)
    σ = model.params.sigma.values
    return σ[i,j]/@f(d,i,j)
end

function a_2(model::SAFTVRMieModel, V, T, z)
    comps = @comps
    m = model.params.segment.values
    m̄ =dot(z,m)/sum(z)
    return m̄/T^2*∑(@f(x_S,i)*@f(x_S,j)*@f(a_2,i,j) for i ∈ comps for j ∈ comps)
end

function a_2(model::SAFTVRMieModel, V, T, z,i,j)
    ϵ = model.params.epsilon.values[i,j]
    λr = model.params.lambda_r.values[i,j]
    λa = model.params.lambda_a.values[i,j]
    x_0ij = @f(x_0,i,j)
    ζₓ = @f(ζ_X)
    C = @f(C,λa,λr)
    KHS = @f(KHS,ζₓ)
    return π*KHS*(1+@f(χ,i,j))*@f(ρ_S)*ϵ^2*@f(d,i,j)^3*C^2 *
        (x_0ij^(2*λa)*(@f(aS_1,2*λa)+@f(B,2*λa,x_0ij))
        - 2*x_0ij^(λa+λr)*(@f(aS_1,λa+λr)+@f(B,λa+λr,x_0ij))
        + x_0ij^(2*λr)*(@f(aS_1,2*λr)+@f(B,2*λr,x_0ij)))
end

function KHS(model::SAFTVRMieModel, V, T, z,ζₓ)
    return (1-ζₓ)^4/(1+4ζₓ+4ζₓ^2-4ζₓ^3+ζₓ^4)
end

function χ(model::SAFTVRMieModel, V, T, z,i,j)
    λr = model.params.lambda_r.values[i,j]
    λa = model.params.lambda_a.values[i,j]
    ζst_ = @f(ζst)
    C = @f(C,λa,λr)
    α = C*(1/(λa-3)-1/(λr-3))
    return @f(f,α,1)*ζst_+@f(f,α,2)*ζst_^5+@f(f,α,3)*ζst_^8
end

function f(model::SAFTVRMieModel, V, T, z, α, m)
    ϕ = SAFTVRMieconsts.ϕ
    return ∑(ϕ[i+1][m]*α^i for i ∈ 0:3)/(1+∑(ϕ[i+1][m]*α^(i-3) for i ∈ 4:6))
end

function ζst(model::SAFTVRMieModel, V, T, z)
    comps = @comps
    σ = model.params.sigma.values
    return @f(ρ_S)*π/6*∑(@f(x_S,i)*@f(x_S,j)*σ[i,j]^3 for i ∈ comps for j ∈ comps)
end

function a_3(model::SAFTVRMieModel, V, T, z)
    comps = @comps
    m = model.params.segment.values
    m̄ =dot(z,m)/sum(z)
    return m̄/T^3* ∑(@f(x_S,i)*@f(x_S,j)*@f(a_3,i,j) for i ∈ comps for j ∈ comps)
end

function a_3(model::SAFTVRMieModel, V, T, z, i, j)
    ϵ = model.params.epsilon.values[i,j]
    λr = model.params.lambda_r.values[i,j]
    λa = model.params.lambda_a.values[i,j]
    ζst_ = ζst(model, V, T, z)
    C = @f(C,λa,λr)
    α = C*(1/(λa-3)-1/(λr-3))
    return -ϵ^3*@f(f,α,4)*ζst_ * exp(@f(f,α,5)*ζst_+@f(f,α,6)*ζst_^2)
end

function a_chain(model::SAFTVRMieModel, V, T, z)
    m = model.params.segment.values
    return -∑(z[i]*(log(@f(g_Mie,i))*(m[i]-1)) for i ∈ @comps)/sum(z)
end

function g_Mie(model::SAFTVRMieModel, V, T, z, i)
    ϵ = model.params.epsilon.diagvalues[i]
    g_HSi = @f(g_HS,i)
    return g_HSi*exp(ϵ/T*@f(g_1,i)/g_HSi+(ϵ/T)^2*@f(g_2,i)/g_HSi);
end

function g_HS(model::SAFTVRMieModel, V, T, z, i)
    x_0ij = @f(x_0,i,i)
    ζₓ = @f(ζ_X)
    k_0 = -log(1-ζₓ)+(42ζₓ-39ζₓ^2+9ζₓ^3-2ζₓ^4)/(6*(1-ζₓ)^3)
    k_1 = (ζₓ^4+6*ζₓ^2-12*ζₓ)/(2*(1-ζₓ)^3)
    k_2 = -3*ζₓ^2/(8*(1-ζₓ)^2)
    k_3 = (-ζₓ^4+3*ζₓ^2+3*ζₓ)/(6*(1-ζₓ)^3)
    return exp(k_0+x_0ij*k_1+x_0ij^2*k_2+x_0ij^3*k_3)
end

function g_1(model::SAFTVRMieModel, V, T, z, i)
    λr = model.params.lambda_r.diagvalues[i]
    λa = model.params.lambda_a.diagvalues[i]
    x_0ij = @f(x_0,i,i)
    return 3*@f(∂a_1╱∂ρ_S,i)-@f(C,λa,λr)*(λa*x_0ij^λa*(@f(aS_1,λa)+@f(B,λa,x_0ij))-λr*x_0ij^λr*(@f(aS_1,λr)+@f(B,λr,x_0ij)))
end

function ∂a_1╱∂ρ_S(model::SAFTVRMieModel, V, T, z, i)
    λr  = model.params.lambda_r.diagvalues[i]
    λa  = model.params.lambda_a.diagvalues[i]
    x_0ij = @f(x_0,i,i)
    C = @f(C,λa,λr)
    return C*(x_0ij^λa*(@f(∂aS_1╱∂ρ_S,λa)+@f(∂B╱∂ρ_S,λa,x_0ij))
                      - x_0ij^λr*(@f(∂aS_1╱∂ρ_S,λr)+@f(∂B╱∂ρ_S,λr,x_0ij)))
end

function ∂aS_1╱∂ρ_S(model::SAFTVRMieModel, V, T, z, λ)
    A  = SAFTVRMieconsts.A
    ζₓ = @f(ζ_X)
    ρ_S = @f(ρ_S)
    ∂ζeff╱∂ρ_S = A * SA[1; 1/λ; 1/λ^2; 1/λ^3] ⋅ SA[1; 2ζₓ; 3ζₓ^2; 4ζₓ^3] * ζₓ/ρ_S
    ζeff_  = @f(ζeff,λ)
    return -1/(λ-3)*((1-ζeff_/2)/(1-ζeff_)^3
            + ρ_S*((3*(1-ζeff_/2)*(1-ζeff_)^2
             - 0.5*(1-ζeff_)^3)/(1-ζeff_)^6)*∂ζeff╱∂ρ_S);
end
ζₓ
function ∂B╱∂ρ_S(model::SAFTVRMieModel, V, T, z, λ, x_0)
    I = (1-x_0^(3-λ))/(λ-3)
    J = (1-(λ-3)*x_0^(4-λ)+(λ-4)*x_0^(3-λ))/((λ-3)*(λ-4))
    ζₓ = @f(ζ_X)

    return ( ((1-ζₓ/2)*I/(1-ζₓ)^3-9*ζₓ*(1+ζₓ)*J/(2*(1-ζₓ)^3))
            + ζₓ*( (3*(1-ζₓ/2)*(1-ζₓ)^2
                - 0.5*(1-ζₓ)^3)*I/(1-ζₓ)^6
                - 9*J*((1+2*ζₓ)*(1-ζₓ)^3
                + ζₓ*(1+ζₓ)*3*(1-ζₓ)^2)/(2*(1-ζₓ)^6) ) );
end

function g_2(model::SAFTVRMieModel,V, T, z, i)
    return (1+@f(γ_c,i))*@f(gMCA_2,i)
end

function γ_c(model::SAFTVRMieModel,V, T, z, i)
    ϵ = model.params.epsilon.diagvalues[i]
    λr = model.params.lambda_r.diagvalues[i]
    λa = model.params.lambda_a.diagvalues[i]
    ζst_ = @f(ζst)
    θ = exp(ϵ/T)-1
    α = @f(C,λa,λr)*(1/(λa-3)-1/(λr-3))
    return 10 * (1-tanh(10*(0.57-ᾱ))) * ζst_*θ*exp(-6.7*ζst_-8*ζst_^2)
    #return ϕ[1][7]*(1-tanh(ϕ[2][7]*(ϕ[3][7]-α)))*ζst_*(exp(ϵ[i]/T)-1)*exp(ϕ[4][7]*ζst_+ϕ[5][7]*ζst_^2)
end

function gMCA_2(model::SAFTVRMieModel, V, T, z, i)
    λr  = model.params.lambda_r.diagvalues[i]
    λa  = model.params.lambda_a.diagvalues[i]
    x_0ij = @f(x_0,i,i)
    ζₓ = @f(ζ_X)
    KHS = @f(KHS,ζₓ)
    return 3*@f(∂a_2╱∂ρ_S,i)- KHS*@f(C,λa,λr)^2 *
    ( λr*x_0ij^(2*λr)*(@f(aS_1,2*λr)+@f(B,2*λr,x_0ij))-
        (λa+λr)*x_0ij^(λa+λr)*(@f(aS_1,λa+λr)+@f(B,λa+λr,x_0ij))+
        λa*x_0ij^(2*λa)*(@f(aS_1,2*λa)+@f(B,2*λa,x_0ij)))
end

function ∂a_2╱∂ρ_S(model::SAFTVRMieModel,V, T, z, i)
    λr = model.params.lambda_r.diagvalues[i]
    λa = model.params.lambda_a.diagvalues[i]
    x_0ij = @f(x_0,i,i)
    ζₓ = @f(ζ_X)
    KHS = @f(KHS,ζₓ)
    ρ_S_ = @f(ρ_S)
    ∂KHS╱∂ρ_S = -ζₓ/ρ_S_ *
    ( (4*(1-ζₓ)^3*(1+4*ζₓ+4*ζₓ^2-4*ζₓ^3+ζₓ^4)
        + (1-ζₓ)^4*(4+8*ζₓ-12*ζₓ^2+4*ζₓ^3))/(1+4*ζₓ+4*ζₓ^2-4*ζₓ^3+ζₓ^4)^2 )
    return 0.5*@f(C,λa,λr)^2 *
    (ρ_S_*∂KHS╱∂ρ_S*(x_0ij^(2*λa)*(@f(aS_1,2*λa)+@f(B,2*λa,x_0ij))
                         - 2*x_0ij^(λa+λr)*(@f(aS_1,λa+λr)+@f(B,λa+λr,x_0ij))
                         + x_0ij^(2*λr)*(@f(aS_1,2*λr)+@f(B,2*λr,x_0ij)))
        + KHS*(x_0ij^(2*λa)*(@f(∂aS_1╱∂ρ_S,2*λa)+@f(∂B╱∂ρ_S,2*λa,x_0ij))
              - 2*x_0ij^(λa+λr)*(@f(∂aS_1╱∂ρ_S,λa+λr)+@f(∂B╱∂ρ_S,λa+λr,x_0ij))
              + x_0ij^(2*λr)*(@f(∂aS_1╱∂ρ_S,2*λr)+@f(∂B╱∂ρ_S,2*λr,x_0ij))))
end

function a_assoc(model::SAFTVRMieModel, V, T, z)
    X_ = @f(X)
    n = model.sites.n_sites
    return ∑(z[i]*∑(n[i][a]*(log(X_[i][a])+(1-X_[i][a])/2) for a ∈ @sites(i)) for i ∈ @comps)/sum(z)
end

function X(model::SAFTVRMieModel, V, T, z)
    _1 = one(V+T+first(z))
    ∑z = ∑(z)
    x = z/∑z
    ρ = N_A*∑z/V
    n = model.sites.n_sites
    itermax = 500
    dampingfactor = 0.5
    error = 1.

    tol = model.absolutetolerance
    iter = 1
    X_ = [[_1 for a ∈ @sites(i)] for i ∈ @comps]
    X_old = deepcopy(X_)
    while error > tol
        iter > itermax && throw("X has failed to converge after " * string(itermax) * " iterations")
        for i ∈ @comps, a ∈ @sites(i)
            rhs = 1/(1+∑(ρ*x[j]*∑(n[j][b]*X_old[j][b]*@f(Δ,i,j,a,b) for b ∈ @sites(j)) for j ∈ @comps))           
            X_[i][a] = (1-dampingfactor)*X_old[i][a] + dampingfactor*rhs
        end
        error = sqrt(∑(∑((X_[i][a] - X_old[i][a])^2 for a ∈ @sites(i)) for i ∈ @comps))
        for i = 1:length(X_)
            X_old[i] .= X_[i]
        end
        iter += 1
    end
    return X_
end

function Δ(model::SAFTVRMieModel, V, T, z, i, j, a, b)
    σ = model.params.sigma.values[i,j]
    ϵ = model.params.epsilon.values[i,j]
    σ3_x = ∑(∑(@f(x_S,i)*@f(x_S,j)*σ^3 for j ∈ @comps) for i ∈ @comps)
    ρR = @f(ρ_S)*σ3_x
    TR = T/ϵ
    c  = SAFTVRMieconsts.c
    I = ∑(∑(c[n+1,m+1]*ρR^n*TR^m for m ∈ 0:(10-n)) for n ∈ 0:10)

    ϵ_assoc = model.params.epsilon_assoc.values[i,j]
    K = model.params.bondvol.values[i,j]
    F = (exp(ϵ_assoc[a,b]/T)-1)
    return F*K[a,b]*I
end

const SAFTVRMieconsts = (
    u = [0.26356031971814109102031,1.41340305910651679221800,3.59642577104072208122300,7.08581000585883755692200,12.6408008442757826594300],
    w = [0.5217556105828086524759,0.3986668110831759274500,7.5942449681707595390e-2,3.6117586799220484545e-3,2.3369972385776227891e-5],

    A = SA[0.81096   1.7888  -37.578   92.284;
    1.02050  -19.341   151.26  -463.50;
    -1.90570   22.845  -228.14   973.92;
    1.08850  -6.1962   106.98  -677.64],

    ϕ = [[7.5365557, -359.440,  1550.9, -1.199320, -1911.2800,  9236.9,  10.0],
        [-37.604630,  1825.60, -5070.1,  9.063632,  21390.175, -129430,  10.0],
        [71.745953, -3168.00,  6534.6, -17.94820, -51320.700,  357230,  0.57],
        [-46.835520,  1884.20, -3288.7,  11.34027,  37064.540, -315530, -6.70],
        [-2.4679820,- 0.82376, -2.7171,  20.52142,  1103.7420,  1390.2, -8.00],
        [-0.5027200, -3.19350,  2.0883, -56.63770, -3264.6100, -4518.2,   NaN],
        [8.0956883,  3.70900,  0.0000,  40.53683,  2556.1810,  4241.6,   NaN]],

    c  = [0.0756425183020431	-0.128667137050961	 0.128350632316055	-0.0725321780970292	   0.0257782547511452  -0.00601170055221687	  0.000933363147191978  -9.55607377143667e-05  6.19576039900837e-06 -2.30466608213628e-07 3.74605718435540e-09
          0.134228218276565	    -0.182682168504886 	 0.0771662412959262	-0.000717458641164565 -0.00872427344283170	0.00297971836051287	 -0.000484863997651451	 4.35262491516424e-05 -2.07789181640066e-06	4.13749349344802e-08 0
         -0.565116428942893	     1.00930692226792   -0.660166945915607	 0.214492212294301	  -0.0388462990166792	0.00406016982985030	 -0.000239515566373142	 7.25488368831468e-06 -8.58904640281928e-08	0	                 0
         -0.387336382687019	    -0.211614570109503	 0.450442894490509	-0.176931752538907	   0.0317171522104923  -0.00291368915845693	  0.000130193710011706  -2.14505500786531e-06  0	                0	                 0
          2.13713180911797	    -2.02798460133021 	 0.336709255682693	 0.00118106507393722  -0.00600058423301506	0.000626343952584415 -2.03636395699819e-05	 0	                   0	                0	                 0
         -0.300527494795524	     2.89920714512243   -0.567134839686498	 0.0518085125423494	  -0.00239326776760414	4.15107362643844e-05  0	                     0	                   0	                0                    0
         -6.21028065719194	    -1.92883360342573	 0.284109761066570	-0.0157606767372364	   0.000368599073256615	0 	                  0	                     0	                   0	                0	                 0
          11.6083532818029	     0.742215544511197  -0.0823976531246117	 0.00186167650098254   0	                0	                  0	                     0	                   0	                0	                 0
         -10.2632535542427	    -0.125035689035085	 0.0114299144831867	 0	                   0	                0	                  0	                     0	                   0	                0	                 0
          4.65297446837297	    -0.00192518067137033 0	                 0	                   0	                0	                  0	                     0	                   0	                0	                 0
         -0.867296219639940	     0	                 0	                 0	                   0	                0	                  0	                     0	                   0	                0	                 0],
)
