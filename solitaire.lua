local solitaire = {}

-- each card is a two-value table
-- first value is color, R, G, B, or F
-- second value is value. 0 is dragon, 1-9 are numbers

COLOR_RED = { 1, 0, 0 }
COLOR_GREEN = { 0, 0.5, 0 }
COLOR_BLACK = { 0, 0, 0 }
COLOR_FLOWER = { 0.5, 0.5, 0 }
COLORS = { COLOR_RED, COLOR_GREEN, COLOR_BLACK, COLOR_FLOWER }

function solitaire.start_game()
    solitaire.seed = math.floor(love.timer.getTime() * 1000000)
    solitaire.rng = love.math.newRandomGenerator()
    solitaire.rng:setSeed(solitaire.seed)

    solitaire.free_cells = { nil, nil, nil }
    solitaire.flower_cell = nil
    solitaire.foundations = { 0, 0, 0 }
    solitaire.board = { {}, {}, {}, {}, {}, {}, {}, {} }
    local deck = {}
    for c = 1, 3 do
        for n = 1, 9 do
            table.insert(deck, { c, n })
        end
        for _ = 1, 4 do
            table.insert(deck, { c, 0 })
        end
    end
    table.insert(deck, { 4, 0 })

    for i = 1, 39 do
        local j = solitaire.rng:random(i, 40)
        deck[i], deck[j] = deck[j], deck[i]
    end

    for i, c in ipairs(deck) do
        table.insert(solitaire.board[(i - 1) % 8 + 1], c)
    end
end

function solitaire.keyreleased(key, scancode)
    if key == "r" then
        solitaire.start_game()
    end
end

function solitaire.update()
end

function solitaire.draw()
    for i, col in ipairs(solitaire.board) do
        love.graphics.push()
        love.graphics.translate(50 * i, 0)
        for j, cd in ipairs(col) do
            love.graphics.push()
            love.graphics.translate(0, 20 * j)
            solitaire.draw_card(0, 0, cd)
            love.graphics.pop()
        end
        love.graphics.pop()
    end
end

function solitaire.draw_card(x, y, cd)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", x, y, 40, 100)
    love.graphics.setColor(COLORS[cd[1]])
    love.graphics.rectangle("line", x, y, 40, 100)
    love.graphics.print(cd[2])
end

function solitaire.legal_move(stack, column)
    -- Always legal to move cards to empty column
    if next(solitaire.board[column]) == nil then
        return true
    end
    local cl = solitaire.board[column]
    local topCardOfCol = cl[#cl]
    local bottomCardOfStack = stack[1]
    -- Always illegal to move stack of cards onto dragon or flower
    if topCardOfCol[2] == 0 or topCardOfCol[1] == 4 then return false end
    -- Number cards must be stacked in descending order and alternating suits
    return bottomCardOfStack[1] ~= topCardOfCol[1] and bottomCardOfStack[1] == topCardOfCol[1] - 1
end

return solitaire
