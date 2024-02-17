### A Pluto.jl notebook ###
# v0.19.38

using Markdown
using InteractiveUtils

# ╔═╡ 929c118b-113b-4fd2-a998-fc54acf70318
using Plots, Clapeyron

# ╔═╡ b9fb451e-cd38-11ee-2d44-e5029c31e244
md"# Activity models"

# ╔═╡ 5c1f7cf7-ad5c-4da1-8528-fe5fe93cd2b0
md"""
In this notebook, we will be giving examples on how to use activity models within `Clapeyron.jl`. We include examples of how one can customise their activity model and how it can be used in tangent with a cubic equation of state.
"""

# ╔═╡ 4b4e4880-b895-44b6-8bb3-1b5cf9a08b77
md"""
## $p-xy$ diagram of water+ethanol

Activity models cannot be used on their own; they provide us with an activity for a species in the mixture but, to obtain VLE properties from this, we need a saturation pressure. This can be obtained from any of the equations of state provided in Clapeyron.jl using the optional argument puremodel. We use the water + ethanol mixture as an example:
"""

# ╔═╡ ec86a5f3-1109-4749-9e1b-575509e0def7
begin
	model1 = Wilson(["water","ethanol"];puremodel=SRK)
	model2 = NRTL(["water","ethanol"];puremodel=PR)
	model3 = UNIFAC(["water","ethanol"];puremodel=PCSAFT)
	model4 = COSMOSACdsp(["water","ethanol"];puremodel=SAFTgammaMie)
	
	models = [model1,model2,model3,model4];
end

# ╔═╡ 2533e27f-0ac2-412f-abc9-7fe13a0b8622
md"We can then obtain the VLE envelope directly using the `bubble_pressure` function:"

# ╔═╡ 858e9f15-1505-4f93-8e69-dfb621662f53
begin
	T = 423.15
	x = range(1e-5,1-1e-5,length=200)
	X = Clapeyron.FractionVector.(x)
	
	y = []
	p = []
	for i ∈ 1:4
	    v0 =[]
	    bub = bubble_pressure.(models[i],T,X)
	    append!(y,[append!([bub[i][4][1] for i ∈ 1:200],reverse(x))])
	    append!(p,[append!([bub[i][1] for i ∈ 1:200],[bub[i][1] for i ∈ 200:-1:1])])
	end
end

# ╔═╡ ca9d0d9a-dc2a-45e3-930f-4ab3c042e760
md"Plotting:"

# ╔═╡ 8a5312a6-a829-4e1c-84d2-a4fb05087ae9
begin
	plot(1 .-y[1], p[1]./1e6, label="Wilson{SRK}", linestyle=:dot, linewidth=5)
end

# ╔═╡ Cell order:
# ╠═b9fb451e-cd38-11ee-2d44-e5029c31e244
# ╠═929c118b-113b-4fd2-a998-fc54acf70318
# ╠═5c1f7cf7-ad5c-4da1-8528-fe5fe93cd2b0
# ╠═4b4e4880-b895-44b6-8bb3-1b5cf9a08b77
# ╠═ec86a5f3-1109-4749-9e1b-575509e0def7
# ╠═2533e27f-0ac2-412f-abc9-7fe13a0b8622
# ╠═858e9f15-1505-4f93-8e69-dfb621662f53
# ╠═ca9d0d9a-dc2a-45e3-930f-4ab3c042e760
# ╠═8a5312a6-a829-4e1c-84d2-a4fb05087ae9
