local solitaire = require("solitaire")

function love.load()
    solitaire.start_game()
end

function love.keyreleased(key, scancode)
    solitaire.keyreleased(key, scancode)
end

function love.update()
    solitaire.update()
end

function love.draw()
    solitaire.draw()
end
