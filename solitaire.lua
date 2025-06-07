local tableext = require("tableext")
local aabb = require("aabb")
local solitaire = {}

-- each card is a two-value table
-- first value is color, R, G, B, or F
-- second value is value. 0 is dragon, 1-9 are numbers

COLOR_RED = { 1, 0, 0 }
COLOR_GREEN = { 0, 1, 0 }
COLOR_BLACK = { 0, 0, 1 }
COLOR_FLOWER = { 0.5, 0.5, 0 }
COLORS = { COLOR_RED, COLOR_GREEN, COLOR_BLACK, COLOR_FLOWER }

CARD_WIDTH = 40
CARD_HEIGHT = 60
STACK_HEIGHT = 20
GAP_WIDTH = 10

BUTTON_GAP = 5
BUTTON_RADIUS = (CARD_HEIGHT - 2 * BUTTON_GAP) / 6

function solitaire.start_game()
    solitaire.seed = math.floor(love.timer.getTime() * 1000000)
    solitaire.rng = love.math.newRandomGenerator()
    solitaire.rng:setSeed(solitaire.seed)

    solitaire.free_cells = { nil, nil, nil }
    solitaire.flower_cell = nil
    solitaire.foundations = { 0, 0, 0 }
    solitaire.board = { {}, {}, {}, {}, {}, {}, {}, {} }

    solitaire.hover = nil

    solitaire.stack = nil
    solitaire.old_column = nil
    solitaire.offset = nil
    solitaire.stack_pos = nil

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

function solitaire.mousemoved(x, y, dx, dy, istouch)
    if solitaire.stack ~= nil then
        solitaire.stack_pos = { x, y }
        return
    end
    local bc = solitaire.check_board_collision(x, y)
    if bc == nil then
        solitaire.hover = nil
        return
    end
    if solitaire.legal_stack(bc[1], bc[2]) then
        solitaire.hover = bc
    else
        solitaire.hover = nil
    end
end

function solitaire.mousepressed(x, y, button, istouch, presses)
    local bc = solitaire.check_board_collision(x, y)
    if bc == nil then return end

    solitaire.pick_up_cards_from_board(bc[1], bc[2])
    local loc = solitaire.card_position_on_board(bc[1], bc[2])
    solitaire.offset = {
        loc[1] - x,
        loc[2] - y
    }
    solitaire.stack_pos = { x, y }
end

function solitaire.mousereleased(x, y, button, istouch, presses)
    if solitaire.stack ~= nil then
        local cdx, cdy = x + solitaire.offset[1], y + solitaire.offset[2]
        local closest_space = nil
        if #solitaire.stack == 1 then
            local cd = solitaire.stack[1]
            for i = 1, 3 do
                if solitaire.free_cells[i] == nil then
                    local dist = (cdx - (CARD_WIDTH + GAP_WIDTH) * (i - 1)) ^ 2 + (cdy) ^ 2
                    if dist < 30 ^ 2 and (closest_space == nil or closest_space[2] > dist) then
                        closest_space = { 2, i }
                    end
                end
            end

            if cd[2] ~= 0 and solitaire.foundations[cd[1]] == cd[2] - 1 then
                local dist = (cdx - (CARD_WIDTH + GAP_WIDTH) * (cd[1] + 4)) ^ 2 + cdy ^ 2
                if dist < 30 ^ 2 and (closest_space == nil or closest_space[2] > dist) then
                    closest_space = { 3, cd[1] }
                end
            end

            if cd[1] == 4 then
                local dist = (cdx - ((CARD_WIDTH + GAP_WIDTH) * 3 + BUTTON_RADIUS * 2 + 20)) ^ 2 + cdy ^ 2
                if dist < 30 ^ 2 and (closest_space == nil or closest_space[2] > dist) then
                    closest_space = { 4 }
                end
            end
        end
        for i, col in ipairs(solitaire.board) do
            local dist = (cdx - (CARD_WIDTH + GAP_WIDTH) * (i - 1)) ^ 2
            if next(col) == nil then
                dist = dist + (cdy - (CARD_HEIGHT + GAP_WIDTH)) ^ 2
            else
                dist = dist + (cdy - (CARD_HEIGHT + GAP_WIDTH + (STACK_HEIGHT) * (#col - 1))) ^ 2
            end
            if dist < 30 ^ 2 and (closest_space == nil or closest_space[2] > dist) then
                closest_space = { 1, i }
            end
        end

        if closest_space ~= nil then
            if closest_space[1] == 1 then
                solitaire.board[closest_space[2]] = tableext.concat({
                    solitaire.board[closest_space[2]], solitaire.stack
                })
            elseif closest_space[1] == 2 then
                solitaire.free_cells[closest_space[2]] = solitaire.stack[1]
            elseif closest_space[1] == 3 then
                solitaire.foundations[closest_space[2]] = solitaire.foundations[closest_space[2]] + 1
            else
                solitaire.flower_cell = { 4, 0 }
            end
            solitaire.stack = nil
            solitaire.old_column = nil
            solitaire.stack_pos = nil
            solitaire.offset = nil
        else
            solitaire.undo_pickup()
        end
    end
end

function solitaire.update()
end

function solitaire.draw()
    -- Board
    love.graphics.push()
    love.graphics.translate(0, CARD_HEIGHT + GAP_WIDTH)
    for i, col in ipairs(solitaire.board) do
        love.graphics.push()
        love.graphics.translate((CARD_WIDTH + GAP_WIDTH) * (i - 1), 0)
        for j, cd in ipairs(col) do
            love.graphics.push()
            love.graphics.translate(0, STACK_HEIGHT * (j - 1))
            local h = solitaire.hover ~= nil and i == solitaire.hover[1] and j >= solitaire.hover[2]
            solitaire.draw_card(0, 0, cd, h)
            love.graphics.pop()
        end
        love.graphics.pop()
    end
    love.graphics.pop()

    -- Free cells
    love.graphics.push()
    for i = 1, 3 do
        love.graphics.push()
        love.graphics.translate((CARD_WIDTH + GAP_WIDTH) * (i - 1), 0)
        local cl = solitaire.free_cells[i]
        if cl == nil then
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.rectangle("line", 0, 0, CARD_WIDTH, CARD_HEIGHT)
        else
            solitaire.draw_card(0, 0, cl, false)
        end
        love.graphics.pop()
    end
    love.graphics.pop()

    -- Foundations
    for i = 1, 3 do
        love.graphics.push()
        love.graphics.translate((CARD_WIDTH + GAP_WIDTH) * (i + 4), 0)
        local cl = solitaire.foundations[i]
        if cl == 0 then
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.rectangle("line", 0, 0, CARD_WIDTH, CARD_HEIGHT)
        else
            solitaire.draw_card(0, 0, { i, cl }, false)
        end
        love.graphics.pop()
    end

    -- Dragon buttons
    for i = 1, 3 do
        love.graphics.push()
        love.graphics.translate((CARD_WIDTH + GAP_WIDTH) * 3 + BUTTON_RADIUS,
            BUTTON_RADIUS + (BUTTON_RADIUS * 2 + BUTTON_GAP) * (i - 1))
        love.graphics.setColor(COLORS[i])
        love.graphics.circle("line", 0, 0, BUTTON_RADIUS)
        love.graphics.pop()
    end

    -- Flower cell
    love.graphics.push()
    love.graphics.translate((CARD_WIDTH + GAP_WIDTH) * 3 + BUTTON_RADIUS * 2 + 20, 0)
    if solitaire.flower_cell == nil then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.rectangle("line", 0, 0, CARD_WIDTH, CARD_HEIGHT)
    else
        solitaire.draw_card(0, 0, solitaire.flower_cell, false)
    end
    love.graphics.pop()

    -- Cards in hand
    if solitaire.stack ~= nil then
        love.graphics.push()
        love.graphics.translate(
            solitaire.stack_pos[1] + solitaire.offset[1],
            solitaire.stack_pos[2] + solitaire.offset[2]
        )
        for j, cd in ipairs(solitaire.stack) do
            love.graphics.push()
            love.graphics.translate(0, STACK_HEIGHT * (j - 1))
            solitaire.draw_card(0, 0, cd, true)
            love.graphics.pop()
        end
        love.graphics.pop()
    end
end

function solitaire.draw_card(x, y, cd, h)
    if h then
        love.graphics.setColor(1, 1, 1)
    else
        love.graphics.setColor(0, 0, 0)
    end
    love.graphics.rectangle("fill", x, y, CARD_WIDTH, CARD_HEIGHT)
    love.graphics.setColor(COLORS[cd[1]])
    love.graphics.rectangle("line", x, y, CARD_WIDTH, CARD_HEIGHT)
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

-- Check if the current column can legally be picked up as a stack.
function solitaire.legal_stack(col, row)
    -- Can't pick up empty column
    if next(solitaire.board[col]) == nil then
        return false
    end
    local cl = solitaire.board[col]
    -- Can't pick up empty row
    if row > #cl then
        return false
    end
    -- Can always pick up top card
    if row == #cl then
        return true
    end
    -- Cannot pick up a dragon or flower with cards on top of it
    if cl[row][2] == 0 then
        return false
    end
    while row < #cl do
        -- If card on top of this one is
        -- - A dragon/flower
        -- - Has the same suit
        -- - Does not have the value of this card minus one
        -- it isn't part of the stack
        if cl[row + 1][2] == 0 or cl[row + 1][1] == cl[row][1] or cl[row + 1][2] ~= cl[row][2] - 1 then
            return false
        end
        row = row + 1
    end
    return true
end

function solitaire.check_board_collision(x, y)
    for i, col in ipairs(solitaire.board) do
        for j, cd in ipairs(col) do
            local a = {
                (CARD_WIDTH + GAP_WIDTH) * (i - 1),
                CARD_HEIGHT + GAP_WIDTH + STACK_HEIGHT * (j - 1),
                CARD_WIDTH,
                STACK_HEIGHT
            }
            if j == #col then
                a[4] = CARD_HEIGHT
            end
            if aabb.contains(a, { x, y }) then
                return { i, j }
            end
        end
    end
    return nil
end

function solitaire.card_position_on_board(col, row)
    return {
        (CARD_WIDTH + GAP_WIDTH) * (col - 1),
        CARD_HEIGHT + GAP_WIDTH + STACK_HEIGHT * (row - 1)
    }
end

function solitaire.pick_up_cards_from_board(col, row)
    local new_stack = tableext.unpack(solitaire.board[col], row)
    solitaire.board[col] = tableext.unpack(solitaire.board[col], 1, row - 1)

    solitaire.stack = new_stack
    solitaire.old_column = col
end

function solitaire.undo_pickup()
    solitaire.board[solitaire.old_column] = tableext.concat({
        solitaire.board[solitaire.old_column], solitaire.stack
    })

    solitaire.stack = nil
    solitaire.old_column = nil
    solitaire.stack_pos = nil
    solitaire.offset = nil
end

return solitaire
