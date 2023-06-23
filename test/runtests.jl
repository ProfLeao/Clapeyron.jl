using Test, Unitful, CoolProp

t1 = @elapsed using Clapeyron
@info "Loading Clapeyron took $(round(t1,digits = 2)) seconds"

#Disable showing citations
ENV["CLAPEYRON_SHOW_REFERENCES"] = "FALSE"

macro printline()  # useful in hunting for where tests get stuck
    file = split(string(__source__.file), "/")[end]
    printstyled("  ", file, ":", __source__.line, "\n", color=:light_black)
end

#fix to current tests
function GERG2008(components::Vector{String};verbose = false)
    return MultiFluid(components;
    mixing = AsymmetricMixing,
    departure = EmpiricDeparture,
    pure_userlocations = String["@REMOVEDEFAULTS","@DB/Empiric/GERG2008/pures"],
    mixing_userlocations  = String["@REMOVEDEFAULTS","@DB/Empiric/GERG2008/mixing/GERG2008_mixing_unlike.csv"],
    departure_userlocations = String["@REMOVEDEFAULTS","@DB/Empiric/GERG2008/departure/GERG2008_departure_unlike.csv"],
    coolprop_userlocations = false,
    verbose = verbose,
    Rgas = Clapeyron.R̄)
end

@testset "All tests" begin
    include("test_database.jl")
    include("test_solvers.jl")
    include("test_differentials.jl")
    include("test_misc.jl")
    include("test_models.jl")
    include("test_methods_eos.jl")
    include("test_methods_api.jl")
    include("test_estimation.jl")
end
