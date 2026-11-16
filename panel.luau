local opened = false
local status = noctalia.state.get("vpn.status") or {}
local username, password = "", ""
local loggingIn = false
local loginError = nil
local choice = 0
local render
local function command(action, server)
    if status.busy then return end
    local cmd = {action = action}
    if server then cmd.ref = server.ref; cmd.name = server.name end
    noctalia.state.set("vpn.command", cmd)
end
local function login()
    if loggingIn or username == "" or password == "" then return end
    loggingIn = true; loginError = nil
    local body = noctalia.json.encode({username = username, password = password})
    password = ""
    render()
    local started = noctalia.http({url = "http://127.0.0.1:2017/api/login", method = "POST",
        headers = {"Content-Type: application/json"}, body = body}, function(response)
        loggingIn = false
        local ok, data = pcall(noctalia.json.decode, response.body or "")
        if ok and response.ok and data.code == "SUCCESS" and data.data and type(data.data.token) == "string" then
            if noctalia.writeFile(noctalia.pluginDataDir() .. "/token", data.data.token) then
                username = ""; command("refresh")
            else loginError = "Не удалось сохранить авторизацию" end
        else loginError = "Не удалось войти. Проверь логин, пароль и доступность v2rayA." end
        render()
    end)
    if not started then loggingIn = false; loginError = "v2rayA недоступен"; render() end
end
render = function()
    if not opened then return end
    local children = {
        ui.row({gap = 10, align = "center"}, {
            ui.glyph({name = "shield-lock", size = 25, color = "primary"}),
            ui.label({text = "v2rayA", fontSize = 22, fontWeight = "bold", flexGrow = 1}),
            ui.button({glyph = "refresh", tooltip = "Обновить", variant = "ghost", controlSize = "sm", enabled = not status.busy,
                onClick = function() command("refresh") end}),
            ui.button({glyph = "x", tooltip = "Закрыть", variant = "ghost", controlSize = "sm", onClick = function() panel.close() end}),
        })
    }
    if not status.auth then
        table.insert(children, ui.label({text = "Вход в локальный v2rayA", fontSize = 16, fontWeight = "bold"}))
        table.insert(children, ui.input({key = "login", value = username, placeholder = "Логин v2rayA", enabled = not loggingIn,
            onChange = function(value) username = value end}))
        table.insert(children, ui.input({key = loggingIn and "password-cleared" or "password", value = password,
            placeholder = "Пароль", password = true, enabled = not loggingIn,
            onChange = function(value) password = value end, onSubmit = login}))
        table.insert(children, ui.button({text = loggingIn and "Вход…" or "Войти", variant = "primary", enabled = not loggingIn, onClick = login}))
        table.insert(children, ui.label({text = loginError or "Пароль не сохраняется. Токен хранится локально с доступом только для тебя.",
            fontSize = 12, color = loginError and "error" or "on_surface_variant", maxLines = 3}))
    else
        table.insert(children, ui.row({gap = 10, align = "center"}, {
            ui.column({gap = 4, flexGrow = 1}, {
                ui.label({text = status.busy and "Применение…" or (status.error and "Нет данных" or (status.running and "VPN включён" or "VPN выключен")),
                    fontSize = 18, fontWeight = "bold"}),
                ui.label({text = status.paused and "Ожидание сети" or ((status.current or "") ~= "" and status.current or "Сервер не выбран"),
                    fontSize = 12, color = "on_surface_variant", maxLines = 3}),
            }),
            ui.toggle({checked = status.running == true, enabled = not status.busy and not status.error,
                onChange = function(value) command(value and "start" or "stop") end}),
        }))
        if status.error then
            table.insert(children, ui.label({text = status.error, color = "error", maxLines = 3}))
        else
            local servers = status.servers or {}
            local options = {}
            for _, server in ipairs(servers) do
                table.insert(options, (server.selected and "● " or "") .. server.name .. (server.group ~= "" and (" · " .. server.group) or ""))
            end
            table.insert(children, ui.label({text = "Сервер", fontSize = 13, color = "on_surface_variant"}))
            table.insert(children, ui.select({key = "servers", options = options, selectedIndex = choice, enabled = not status.busy and #servers > 0,
                onChange = function(value) choice = tonumber(value) or 0 end}))
            table.insert(children, ui.button({text = "Выбрать сервер", glyph = "check", variant = "primary", enabled = not status.busy and #servers > 0,
                onClick = function() local s = servers[choice + 1]; if s then command("select", s) end end}))
            table.insert(children, ui.label({text = "Выбор применится сразу. Если VPN выключен, он останется выключенным.",
                fontSize = 11, maxLines = 3, color = "on_surface_variant"}))
        end
    end
    table.insert(children, ui.button({text = "Открыть v2rayA в браузере", glyph = "external-link", variant = "ghost", controlSize = "sm",
        onClick = function() noctalia.runAsync({"xdg-open", "http://127.0.0.1:2017"}) end}))
    panel.render(ui.column({gap = 12, padding = 10}, children))
end
noctalia.state.watch("vpn.status", function(value)
    status = value or {}
    if choice >= #(status.servers or {}) then choice = 0 end
    render()
end)
function onOpen()
    opened = true; status = noctalia.state.get("vpn.status") or {}
    choice = 0
    for i, server in ipairs(status.servers or {}) do if server.selected then choice = i - 1; break end end
    command("refresh"); render()
end
function onClose() opened = false; password = ""; loginError = nil end
