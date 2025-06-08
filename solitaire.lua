local smoothstep = require("smoothstep")
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

LOC_BOARD = 1
LOC_FREE_CELL = 2
LOC_FOUNDATION = 3
LOC_FLOWER_CELL = 4

function solitaire.start_game()
    solitaire.seed = math.floor(love.timer.getTime() * 1000000)
    solitaire.rng = love.math.newRandomGenerator()
    solitaire.rng:setSeed(solitaire.seed)

    solitaire.free_cells = { nil, nil, nil }
    solitaire.flower_cell = nil
    solitaire.foundations = { 0, 0, 0 }
    solitaire.board = { {}, {}, {}, {}, {}, {}, {}, {} }

    solitaire.hover = nil
    solitaire.dragon_hover = nil

    solitaire.stack = nil
    solitaire.old_column = nil
    solitaire.offset = nil
    solitaire.stack_pos = nil

    solitaire.dragons = { {}, {}, {} }
    solitaire.movable_dragons = { nil, nil, nil }

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

    solitaire.after_move()
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

    local bc = solitaire.cards_at_location(x, y)
    if bc == nil then
        solitaire.hover = nil
    else
        if bc[1] == LOC_FREE_CELL or solitaire.legal_stack(bc[2][1], bc[2][2]) then
            solitaire.hover = bc
        else
            solitaire.hover = nil
        end
    end

    -- Dragon hover
    solitaire.dragon_hover = nil
    for i = 1, 3 do
        local bx, by = solitaire.dragon_button_position(i)
        local d = math.sqrt((x - bx) ^ 2 + (y - by) ^ 2)
        if d < BUTTON_RADIUS then
            solitaire.dragon_hover = i
        end
    end
end

function solitaire.mousepressed(x, y, button, istouch, presses)
    if solitaire.animation == nil then
        local bc = solitaire.cards_at_location(x, y)
        if bc == nil then return end

        solitaire.pick_up_cards_from_board(bc)
        local locx, locy = solitaire.card_position(bc)
        solitaire.offset = {
            locx - x,
            locy - y
        }
        solitaire.stack_pos = { x, y }
    end
end

function solitaire.mousereleased(x, y, button, istouch, presses)
    if solitaire.stack ~= nil then
        local cdx, cdy = x + solitaire.offset[1], y + solitaire.offset[2]
        local closest_space = nil
        if #solitaire.stack == 1 then
            local cd = solitaire.stack[1]
            for i = 1, 3 do
                if solitaire.free_cells[i] == nil then
                    local sx, sy = solitaire.free_cell_position(i)
                    local dist = (cdx - sx) ^ 2 + (cdy - sy) ^ 2
                    if dist < 30 ^ 2 and (closest_space == nil or closest_space[2] > dist) then
                        closest_space = { LOC_FREE_CELL, i }
                    end
                end
            end

            if cd[2] ~= 0 and solitaire.foundations[cd[1]] == cd[2] - 1 then
                local sx, sy = solitaire.foundation_position(cd[1])
                local dist = (cdx - sx) ^ 2 + (cdy - sy) ^ 2
                if dist < 30 ^ 2 and (closest_space == nil or closest_space[2] > dist) then
                    closest_space = { LOC_FOUNDATION, cd[1] }
                end
            end

            if cd[1] == 4 then
                local sx, sy = solitaire.flower_position()
                local dist = (cdx - sx) ^ 2 + (cdy - sy) ^ 2
                if dist < 30 ^ 2 and (closest_space == nil or closest_space[2] > dist) then
                    closest_space = { LOC_FLOWER_CELL }
                end
            end
        end
        for i, col in ipairs(solitaire.board) do
            local sx, sy
            if next(col) == nil then
                sx, sy = solitaire.board_position(i, 1)
            else
                sx, sy = solitaire.board_position(i, #col)
            end
            local dist = (cdx - sx) ^ 2 + (cdy - sy) ^ 2
            if dist < 30 ^ 2 and (closest_space == nil or closest_space[2] > dist) then
                closest_space = { LOC_BOARD, i }
            end
        end

        if closest_space ~= nil then
            if closest_space[1] == LOC_BOARD then
                solitaire.board[closest_space[2]] = tableext.concat({
                    solitaire.board[closest_space[2]], solitaire.stack
                })
            elseif closest_space[1] == LOC_FREE_CELL then
                solitaire.free_cells[closest_space[2]] = solitaire.stack[1]
            elseif closest_space[1] == LOC_FOUNDATION then
                solitaire.foundations[closest_space[2]] = solitaire.foundations[closest_space[2]] + 1
            else
                solitaire.flower_cell = { LOC_FLOWER_CELL, 0 }
            end

            solitaire.stack = nil
            solitaire.old_column = nil
            solitaire.stack_pos = nil
            solitaire.offset = nil
            solitaire.after_move()
        else
            solitaire.undo_pickup()
        end
    end
end

function solitaire.update(dt)
    if solitaire.animation ~= nil then
        solitaire.animation.t = solitaire.animation.t + dt
        if solitaire.animation.t > solitaire.animation.duration then
            if solitaire.animation.card[1] == 4 then
                solitaire.flower_cell = solitaire.animation.card
            else
                solitaire.foundations[solitaire.animation.card[1]] = solitaire.animation.card[2]
            end
            solitaire.animation = nil
            solitaire.after_move()
        end
    end
end

function solitaire.draw()
    -- Board
    for i, col in ipairs(solitaire.board) do
        for j, cd in ipairs(col) do
            local cx, cy = solitaire.board_position(i, j)
            local h = false
            if solitaire.hover ~= nil and solitaire.hover[1] == LOC_BOARD and
                solitaire.hover[2][1] == i and solitaire.hover[2][2] == j then
                h = true
            end
            if solitaire.dragon_hover ~= nil and cd[2] == 0 and cd[1] == solitaire.dragon_hover then
                h = true
            end
            solitaire.draw_card(cx, cy, cd, h)
        end
    end

    -- Free cells
    for i = 1, 3 do
        local fx, fy = solitaire.free_cell_position(i)
        local cl = solitaire.free_cells[i]
        local h = false
        if solitaire.hover ~= nil and solitaire.hover[1] == LOC_FREE_CELL and
            solitaire.hover[2] == i then
            h = true
        end
        if solitaire.dragon_hover ~= nil and cl ~= nil
            and cl[2] == 0 and cl[1] == solitaire.dragon_hover then
            h = true
        end
        solitaire.draw_card(fx, fy, cl, h)
    end

    -- Foundations
    for i = 1, 3 do
        local fx, fy = solitaire.foundation_position(i)
        local cl = solitaire.foundations[i]
        if cl == 0 then
            solitaire.draw_card(fx, fy, nil, false)
        else
            solitaire.draw_card(fx, fy, { i, cl }, false)
        end
    end

    -- Dragon buttons
    for i = 1, 3 do
        local bx, by = solitaire.dragon_button_position(i)
        if solitaire.movable_dragons[i] ~= nil then
            love.graphics.setColor(1, 1, 1)
            love.graphics.circle("fill", bx, by, BUTTON_RADIUS)
        end
        love.graphics.setColor(COLORS[i])
        love.graphics.circle("line", bx, by, BUTTON_RADIUS)
    end

    -- Flower cell
    local fx, fy = solitaire.flower_position()
    solitaire.draw_card(fx, fy, solitaire.flower_cell, false)

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

    if solitaire.animation ~= nil then
        solitaire.draw_card_animation(solitaire.animation)
    end
end

function solitaire.draw_card(x, y, cd, h)
    if cd == nil then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.rectangle("line", x, y, CARD_WIDTH, CARD_HEIGHT)
        return
    end
    if h then
        love.graphics.setColor(1, 1, 1)
    else
        love.graphics.setColor(0, 0, 0)
    end
    love.graphics.rectangle("fill", x, y, CARD_WIDTH, CARD_HEIGHT)
    love.graphics.setColor(COLORS[cd[1]])
    love.graphics.rectangle("line", x, y, CARD_WIDTH, CARD_HEIGHT)
    love.graphics.print(cd[2], x, y)
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

function solitaire.cards_at_location(x, y)
    for i, col in ipairs(solitaire.board) do
        for j = 1, #col do
            local px, py = solitaire.board_position(i, j)
            local a = {
                px, py,
                CARD_WIDTH,
                STACK_HEIGHT
            }
            if j == #col then
                a[4] = CARD_HEIGHT
            end
            if aabb.contains(a, { x, y }) then
                return { LOC_BOARD, { i, j } }
            end
        end
    end
    return nil
end

function solitaire.board_position(col, row)
    return
        (CARD_WIDTH + GAP_WIDTH) * (col - 1),
        CARD_HEIGHT + GAP_WIDTH + STACK_HEIGHT * (row - 1)
end

function solitaire.free_cell_position(i)
    return (CARD_WIDTH + GAP_WIDTH) * (i - 1), 0
end

function solitaire.foundation_position(i)
    return (CARD_WIDTH + GAP_WIDTH) * (i + 4), 0
end

function solitaire.flower_position()
    return (CARD_WIDTH + GAP_WIDTH) * 3 + BUTTON_RADIUS * 2 + 20, 0
end

function solitaire.dragon_button_position(i)
    return (CARD_WIDTH + GAP_WIDTH) * 3 + BUTTON_RADIUS,
        BUTTON_RADIUS + (BUTTON_RADIUS * 2 + BUTTON_GAP) * (i - 1)
end

function solitaire.card_position(p)
    if p[1] == LOC_FREE_CELL then
        return solitaire.free_cell_position(p[2])
    elseif p[1] == LOC_FOUNDATION then
        return solitaire.foundation_position(p[2])
    elseif p[1] == LOC_FLOWER_CELL then
        return solitaire.flower_position()
    else
        return solitaire.board_position(p[2][1], p[2][2])
    end
end

function solitaire.pick_up_cards_from_board(pos)
    if pos[1] == LOC_BOARD then
        local col, row = pos[2][1], pos[2][2]
        local new_stack = tableext.unpack(solitaire.board[col], row)
        solitaire.board[col] = tableext.unpack(solitaire.board[col], 1, row - 1)

        solitaire.stack = new_stack
        solitaire.old_column = col
    end
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

function solitaire.check_automoves()
    local top_cards = {}
    for i = 1, 3 do
        if solitaire.free_cells[i] ~= nil then
            table.insert(top_cards, { LOC_FREE_CELL, i })
        end
    end

    for i, col in ipairs(solitaire.board) do
        if next(col) ~= nil then
            table.insert(top_cards, { LOC_BOARD, { i, #col } })
        end
    end

    for _, cp in ipairs(top_cards) do
        local cd = {}
        if cp[1] == LOC_FREE_CELL then
            cd = solitaire.free_cells[cp[2]]
        else
            cd = solitaire.board[cp[2][1]][cp[2][2]]
        end

        -- Can automove a card if
        -- - It is a flower card, OR
        -- - It is not a dragon card AND
        -- - Destination is 1 less in value than this card AND
        -- - No other cards can be placed on this card
        -- ex. for a green 5, all red or blue 4s must be in the foundations
        if cd[1] == 4 then return cp end

        if cd[2] ~= 0 and solitaire.foundations[cd[1]] == cd[2] - 1 then
            -- 2 card does not need to worry about any cards being placed on it,
            -- as 1 cards are immediately played to foundations
            if cd[2] == 2 then return cp end
            local bad = false
            for i = 1, 3 do
                if i ~= cd[1] and solitaire.foundations[i] <= cd[2] - 2 then
                    bad = true
                end
            end
            if not bad then
                return cp
            end
        end
    end
end

function solitaire.after_move()
    local automove = solitaire.check_automoves()
    if automove ~= nil then
        local anim = {
            t = 0,
            duration = 0.5,
        }
        anim.startX, anim.startY = solitaire.card_position(automove)
        if automove[1] == LOC_FREE_CELL then
            anim.card = solitaire.free_cells[automove[2]]
            solitaire.free_cells[automove[2]] = nil
        else
            anim.card = solitaire.board[automove[2][1]][automove[2][2]]
            table.remove(solitaire.board[automove[2][1]], automove[2][2])
        end
        if anim.card[1] == 4 then
            anim.endX, anim.endY = solitaire.flower_position()
        else
            anim.endX, anim.endY = solitaire.foundation_position(anim.card[1])
        end
        solitaire.animation = anim

        return
    end

    -- Check position of all dragons in free cells and top of board
    solitaire.dragons = { {}, {}, {} }
    solitaire.movable_dragons = { nil, nil, nil }

    local open_free_cell = nil

    for i = 1, 3 do
        if solitaire.free_cells[i] ~= nil then
            if solitaire.free_cells[i][2] == 0 then
                table.insert(solitaire.dragons[solitaire.free_cells[i][1]], { LOC_FREE_CELL, i })
            end
        elseif open_free_cell == nil then
            open_free_cell = i
        end
    end

    for i, col in ipairs(solitaire.board) do
        if next(col) ~= nil then
            local top_card = col[#col]
            if top_card[2] == 0 then
                table.insert(solitaire.dragons[top_card[1]], { LOC_BOARD, { i, #col } })
            end
        end
    end

    for i = 1, 3 do
        -- All 4 dragons have to be exposed
        if #solitaire.dragons[i] == 4 then
            for j, dgp in ipairs(solitaire.dragons[i]) do
                -- If one of the dragons is in a free cell, move all dragons to that free cell
                if dgp[1] == LOC_FREE_CELL and solitaire.movable_dragons[i] == nil then
                    solitaire.movable_dragons[i] = dgp[2]
                end
            end
            -- If there is an open free cell, you can move all dragons to that cell
            if open_free_cell ~= nil and solitaire.movable_dragons[i] == nil then
                solitaire.movable_dragons[i] = open_free_cell
            end
        end
    end
end

function solitaire.draw_card_animation(anim)
    local t = smoothstep(anim.t / anim.duration)
    local xx, yy = anim.startX * (1 - t) + anim.endX * t, anim.startY * (1 - t) + anim.endY * t
    solitaire.draw_card(xx, yy, anim.card, false)
end

return solitaire
