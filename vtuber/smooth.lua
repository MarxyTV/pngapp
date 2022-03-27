function lerp(a,b,t) return (1-t)*a + t*b end
function lerp2(a,b,t) return a+(b-a)*t end

function quadin(a, b, dt)
    return lerp(a, b, dt * dt)
end

function quad_in_out(a, b, dt)
    if dt <= 0.5 then
        return quadin(a, b, dt * 2) - (b - a) / 2 -- scale by 2 / 0.5
    else
        return quadin(a, b, (1 - dt) * 2) + (b - a) / 2 -- reverse and offset by 0.5
    end
end