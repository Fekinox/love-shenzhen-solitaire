local solitaire = require("solitaire")

function love.load()
    solitaire.start_game()
end

function love.keyreleased(key, scancode)
    solitaire.keyreleased(key, scancode)
end

function love.mousemoved(x, y, dx, dy, istouch)
    solitaire.mousemoved(x, y, dx, dy, istouch)
end

function love.mousepressed(x, y, button, istouch, presses)
    solitaire.mousepressed(x, y, button, istouch, presses)
end

function love.mousereleased(x, y, button, istouch, presses)
    solitaire.mousereleased(x, y, button, istouch, presses)
end

function love.update(dt)
    solitaire.update(dt)
end

function love.draw()
    solitaire.draw()
end
