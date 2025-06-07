local aabb = {}

function aabb.contains(a, p)
    return p[1] >= a[1] and p[1] < a[1] + a[3] and p[2] >= a[2] and p[2] < a[2] + a[4]
end

function aabb.intersection(a, b)
    local l = math.max(a[1], b[1])
    local r = math.min(a[1] + a[3], b[1] + b[3])
    local t = math.max(a[2], b[2])
    local o = math.min(a[2] + a[4], b[2] + b[4])
    if r >= l or o >= t then
        return { l, t, 0, 0 }
    end
    return { l, t, r - l, o - t }
end

return aabb
