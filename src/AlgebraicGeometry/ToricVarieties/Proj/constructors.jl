@doc raw"""
    proj(E::ToricLineBundle...)

This function computes the projectivization of a direct sum of line bundles or divisors.
Please see [OM78](@cite) for more background information.

# Examples
Let us construct the projective bundles ``X=\mathbb{P}(\mathcal{O}_{\mathbb{P}^1}\oplus\mathcal{O}_{\mathbb{P}^1}(1))`` and ``Y=\mathbb{P}(\mathcal{O}_{\mathbb{P}^1}\oplus\mathcal{O}_{\mathbb{P}^1}(2))``.
```jldoctest
julia> P1 = projective_space(NormalToricVariety, 1);

julia> D0 = toric_divisor(P1, [0,0]);

julia> D1 = toric_divisor(P1, [1,0]);

julia> X = proj(D0, D1)
Normal toric variety

julia> L0 = toric_line_bundle(P1, [0]);

julia> L1 = toric_line_bundle(P1, [2]);

julia> Y = proj(L0, L1)
Normal toric variety
```
"""
function proj(E::ToricLineBundle...)
  return _proj([E...])
end

function proj(E::ToricDivisor...)
  return _proj([E...])
end

function proj()
	@req false "The direct sum is empty."
end

function _proj(E::Vector{T}) where T <: Union{ToricDivisor, ToricLineBundle}

  v = toric_variety(E[1])

  length(E) == 1 && return v

  @req all(i -> toric_variety(E[i]) == v, eachindex(E)) "The divisors are defined on different toric varieties."

  PF_Pr = normal_fan(simplex(length(E) - 1))
  l = rays(PF_Pr)

  modified_ray_gens = Dict{RayVector{QQFieldElem}, RayVector{QQFieldElem}}()

  for sigma in maximal_cones(v)
    pol_sigma = polarize(sigma)
    for ray in rays(sigma)
      ray in keys(modified_ray_gens) && continue
      modified_ray_gens[ray] = vcat(ray, -sum(i -> dot(_m_sigma(sigma, pol_sigma, E[i]), ray) * l[i], eachindex(E)))
    end
    length(keys(modified_ray_gens)) == nrays(v) && break
  end

  new_maximal_cones = Vector{Vector{Int64}}(undef, n_maximal_cones(v) * length(E))
  index = 1

  for a in 1:n_maximal_cones(v)
    first = [row(ray_indices(maximal_cones(v)), a)...]
    for b in eachindex(E)
      second = [row(ray_indices(maximal_cones(PF_Pr)), b)...] .+ nrays(v)
      new_maximal_cones[index] = vcat(first, second)
      index += 1
    end
  end

  total_rays_gens = vcat([modified_ray_gens[ray] for ray in rays(v)], [vcat(RayVector(zeros(Int64, dim(v))), l[i]) for i in eachindex(E)])

  return normal_toric_variety(polyhedral_fan(total_rays_gens, IncidenceMatrix(new_maximal_cones)))
end

function _m_sigma(sigma::Cone{QQFieldElem}, pol_sigma::Cone{QQFieldElem}, D::Union{ToricDivisor, ToricLineBundle})::RayVector{QQFieldElem}

  ans = RayVector(zeros(QQFieldElem, dim(sigma)))
  coeff = coefficients(isa(D, ToricDivisor) ? D : toric_divisor(D))

  dual_ray = QQFieldElem[]

  for ray in rays(sigma)
    for pol_ray in rays(pol_sigma)
      dot(ray, pol_ray) == 0 && continue
      dual_ray = lcm(denominator.(pol_ray)) * pol_ray
      break
    end
    i = findfirst(j -> j == ray, rays(toric_variety(D)))
    ans -= coeff[i] * dual_ray
  end

  return ans
end
