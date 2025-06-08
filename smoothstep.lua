local smoothstep = function(t)
    t = math.max(0, math.min(1, t))
    return t * t * (3.0 - 2.0 * t)
end

return smoothstep
