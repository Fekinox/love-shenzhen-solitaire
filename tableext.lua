local tableext = {}

function tableext.unpack(t, i, j)
    if j == nil then j = #t end
    if i == nil then i = 1 end
    local res = {}
    for k = i, j do
        table.insert(res, t[k])
    end
    return res
end

function tableext.concat(ts)
    local res = {}
    for _, t in ipairs(ts) do
        for _, a in ipairs(t) do
            table.insert(res, a)
        end
    end
    return res
end

return tableext
