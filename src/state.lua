local state = {
    currentState = nil,
}

function state.switch(nextState, ...)
    local previous = state.currentState

    if previous and previous.leave then
        previous:leave()
    end

    state.currentState = nextState

    if state.currentState and state.currentState.enter then
        state.currentState:enter(previous, ...)
    end
end

function state.current()
    return state.currentState
end

return state