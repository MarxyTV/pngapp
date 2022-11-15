function sliderElement(ui, label, min, current, max, step, decimals, suffix)
    ui:layoutRow('dynamic', 25, 2)
    ui:label(label)
    ui:label(round(current, decimals) .. (suffix or ''), 'right')
    ui:layoutRow('dynamic', 25, 1)
    return ui:slider(min, current, max, step)
end
