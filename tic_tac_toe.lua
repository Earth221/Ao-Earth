-- GLOBAL VARIABLES

-- Game progression modes in a loop:
-- [Not-Started] -> Waiting -> Playing -> [Someone wins or draw] -> Waiting...
GameMode = GameMode or "Not-Started"
StateChangeTime = StateChangeTime or nil

-- State durations (in milliseconds)
WAIT_TIME = 2 * 60 * 1000  -- 2 minutes for players to join
TURN_TIME = 30 * 1000  -- 30 seconds for each player's turn
NOW = NOW or nil  -- Current time, updated on every message.

-- Token information for player stakes.
PAYMENT_TOKEN = PAYMENT_TOKEN or "CRED"  -- Token address

-- Players waiting to join the next game and their payment status.
WaitingPlayers = WaitingPlayers or {}
-- Active players and their token states.
ActivePlayers = ActivePlayers or {}
-- Current player's turn
CurrentPlayer = CurrentPlayer or nil
-- Tic Tac Toe board setup
BOARD_SIZE = 3
EMPTY = " "
X_TOKEN = "X"
O_TOKEN = "O"
-- Default player state initialization.
function initializePlayerState()
    return {
        Tokens = {},  -- Tokens placed on the board
    }
end

-- Sends a state change announcement to all registered listeners.
-- @param event: The event type or name.
-- @param description: Description of the event.
function announce(event, description)
    for _, address in pairs(Listeners) do
        ao.send({
            Target = address,
            Action = "Announcement",
            Event = event,
            Data = description
        })
    end
    return print("Announcement: " .. event .. " " .. description)
end

-- Sends a reward to a player.
-- @param recipient: The player receiving the reward.
-- @param qty: The quantity of the reward.
-- @param reason: The reason for the reward.
function sendReward(recipient, qty, reason)
    qty = tonumber(qty)
    ao.send({
        Target = PAYMENT_TOKEN,
        Action = "Transfer",
        Quantity = tostring(qty),
        Recipient = recipient,
        Reason = reason
    })
    return print("Sent Reward: " .. tostring(qty) .. " tokens to " .. recipient .. " " .. reason)
end

-- Starts the waiting period for players to become ready to play.
function startWaitingPeriod()
    GameMode = "Waiting"
    StateChangeTime = NOW + WAIT_TIME
    announce("Started-Waiting-Period", "The game is about to begin! Send your token to take part.")
    print('Starting Waiting Period')
end

-- Starts the game if there are enough players.
function startGamePeriod()
    local paidPlayers = 0
    for player, hasPaid in pairs(WaitingPlayers) do
        if hasPaid then
            paidPlayers = paidPlayers + 1
        end
    end

    if paidPlayers < 2 then
        announce("Not-Enough-Players", "Not enough players registered! Restarting...")
        for player, hasPaid in pairs(WaitingPlayers) do
            if hasPaid then
                WaitingPlayers[player] = false
                sendReward(player, 1, "Refund")
            end
        end
        startWaitingPeriod()
        return
    end

    GameMode = "Playing"
    StateChangeTime = NOW + TURN_TIME
    for player, hasPaid in pairs(WaitingPlayers) do
        if hasPaid then
            ActivePlayers[player] = initializePlayerState()
        else
            ao.send({
                Target = player,
                Action = "Ejected",
                Reason = "Did-Not-Pay"
            })
            removeListener(player) -- Removing player from listener if they didn't pay
        end
    end
    CurrentPlayer = next(ActivePlayers) -- Selecting the first player
    announce("Started-Game", "The Tic Tac Toe game has started. Good luck!")
    print("Game Started....")
end

-- Ends the current game and starts a new one.
function endGame(result)
    print("Game Over")

    if result == "Draw" then
        for player, _ in pairs(ActivePlayers) do
            sendReward(player, 1, "Draw")
        end
        announce("Game-Ended", "The game ended in a draw!")
    else
        sendReward(result, 2, "Win") -- Reward winner
        sendReward(next(ActivePlayers), 1, "Loss") -- Compensate other player
        announce("Game-Ended", "Congratulations! The game has ended. Winner: " .. result .. ".")
    end

    ActivePlayers = {}
    startWaitingPeriod()
end

-- Removes a listener from the listeners' list.
-- @param listener: The listener to be removed.
function removeListener(listener)
    for i, v in ipairs(Listeners) do
        if v == listener then
            table.remove(Listeners, i)
            break
        end
    end
end

-- Checks if a player has won the game.
function checkWin(player)
    local tokens = ActivePlayers[player].Tokens

    -- Check rows and columns
    for i = 1, BOARD_SIZE do
        if tokens[i][1] == tokens[i][2] and tokens[i][2] == tokens[i][3] and tokens[i][1] ~= EMPTY then
            return true
        end
        if tokens[1][i] == tokens[2][i] and tokens[2][i] == tokens[3][i] and tokens[1][i] ~= EMPTY then
            return true
        end
    end

    -- Check diagonals
    if tokens[1][1] == tokens[2][2] and tokens[2][2] == tokens[3][3] and tokens[1][1] ~= EMPTY then
        return true
    end
    if tokens[1][3] == tokens[2][2] and tokens[2][2] == tokens[3][1] and tokens[1][3] ~= EMPTY then
        return true
    end

    return false
end

-- Checks if the game is a draw.
function checkDraw()
    local tokens = ActivePlayers[CurrentPlayer].Tokens

    for i = 1, BOARD_SIZE do
        for j = 1, BOARD_SIZE do
            if tokens[i][j] == EMPTY then
                return false
            end
        end
    end

    return true
end

-- Handles the end of a turn.
function endTurn()
    StateChangeTime = NOW + TURN_TIME
    CurrentPlayer = next(ActivePlayers, CurrentPlayer) or next(ActivePlayers)
    announce("Next-Turn", "It's now " .. CurrentPlayer .. "'s turn.")
end

-- HANDLERS: Game state management

-- Handler for cron messages, manages game state transitions.
Handlers.add(
    "Game-State-Timers",
    function(Msg)
        return "continue"
    end,
    function(Msg)
        NOW = Msg.Timestamp
        if GameMode == "Not-Started" then
            startWaitingPeriod()
        elseif GameMode == "Waiting" then
            if NOW > StateChangeTime then
                startGamePeriod()
