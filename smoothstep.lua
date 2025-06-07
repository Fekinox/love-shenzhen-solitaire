local smoothstep = function(t)
    return t * t * (3.0 - 2.0 * t)
end

return smoothstep
