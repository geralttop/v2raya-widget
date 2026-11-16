local status = noctalia.state.get("vpn.status") or {}
local function render()
    local color = status.error and "error" or (status.running and not status.paused and "primary" or "on_surface_variant")
    local title = status.error or (status.paused and "VPN: ожидание сети" or (status.running and "VPN включён" or "VPN выключен"))
    barWidget.setTooltip(title .. ((status.current or "") ~= "" and ("\n" .. status.current) or ""))
    local children = {ui.glyph({name = "shield-lock", color = color})}
    if not barWidget.isVertical() then table.insert(children, ui.label({text = "VPN", color = color})) end
    barWidget.render(ui.row({gap = 5, align = "center"}, children))
end
noctalia.state.watch("vpn.status", function(s) status = s or {}; render() end)
function update() render() end
function onClick() noctalia.togglePanel("geralttop/v2raya:control") end
function onRightClick()
    if status.auth and not status.error and not status.busy then
        noctalia.state.set("vpn.command", {action = status.running and "stop" or "start"})
    else noctalia.togglePanel("geralttop/v2raya:control") end
end
render()
