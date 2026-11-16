local busy = false
local BASE = "http://127.0.0.1:2017/api/"
local function publish(value)
    noctalia.state.set("vpn.status", value)
end
local function request(method, path, body, callback)
    local token = noctalia.readFile(noctalia.pluginDataDir() .. "/token")
    if not token or token == "" then
        publish({auth = false, error = "Войди в аккаунт v2rayA"})
        busy = false
        return
    end
    local started = noctalia.http({url = BASE .. path, method = method,
        headers = {"Content-Type: application/json", "Authorization: Bearer " .. token},
        body = body and noctalia.json.encode(body) or ""}, function(response)
        local ok, data = pcall(noctalia.json.decode, response.body or "")
        if not ok or type(data) ~= "table" then
            publish({auth = true, error = "v2rayA недоступен"}); busy = false; return
        end
        if response.status == 401 or data.code == "UNAUTHORIZED" then
            publish({auth = false, error = "Войди в аккаунт v2rayA"}); busy = false; return
        end
        if not response.ok or data.code ~= "SUCCESS" then
            publish({auth = true, error = tostring(data.message or "Ошибка v2rayA")}); busy = false; return
        end
        callback(data.data)
    end)
    if not started then busy = false; publish({auth = true, error = "Не удалось обратиться к v2rayA"}) end
end
local function normalize(data)
    local touch = data.touch or {}
    local connected = touch.connectedServer or {}
    local servers = {}
    local names = {}
    local hasPinned = false
    for _, item in ipairs(connected) do
        if item.outbound == "proxy" and item.selected then hasPinned = true end
    end
    local function add(server, sub, group)
        local selected = false
        for _, item in ipairs(connected) do
            if (item.outbound == "proxy" or item.outbound == "") and item.id == server.id
                and (item.sub or 0) == sub and item._type == server._type then selected = not hasPinned or item.selected == true end
        end
        local ref = {id = server.id, sub = sub, _type = server._type, outbound = "proxy"}
        table.insert(servers, {name = server.name or "Сервер", group = group, ref = ref, selected = selected})
        if selected then table.insert(names, server.name or "Сервер") end
    end
    for _, server in ipairs(touch.servers or {}) do add(server, 0, "") end
    for _, sub in ipairs(touch.subscriptions or {}) do
        for _, server in ipairs(sub.servers or {}) do add(server, sub.id - 1, sub.remarks or sub.host or "Подписка") end
    end
    return {auth = true, running = data.running == true, paused = data.networkPaused == true,
        servers = servers, current = table.concat(names, ", ")}
end
function update()
    if busy then return end
    busy = true
    request("GET", "touch", nil, function(data) busy = false; publish(normalize(data)) end)
end
noctalia.state.watch("vpn.command", function(cmd)
    if not cmd then return end
    noctalia.state.set("vpn.command", nil)
    if busy then return end
    if cmd.action == "refresh" then update(); return end
    busy = true
    local status = noctalia.state.get("vpn.status") or {}
    status.busy = true; publish(status)
    local method, path, body
    if cmd.action == "start" then method = "POST"; path = "v2ray"
    elseif cmd.action == "stop" then method = "DELETE"; path = "v2ray"
    elseif cmd.action == "select" then
        -- Validate against a fresh server list; never trust a stale index.
        request("GET", "touch", nil, function(data)
            local fresh = normalize(data)
            for _, s in ipairs(fresh.servers) do
                if s.ref.id == cmd.ref.id and s.ref.sub == cmd.ref.sub and s.ref._type == cmd.ref._type and s.name == cmd.name then
                    request("PUT", "outboundConnections", {outbound = "proxy", touches = {s.ref}}, function()
                        busy = false; update()
                    end)
                    return
                end
            end
            busy = false; fresh.error = "Список серверов изменился. Выбери сервер ещё раз."; publish(fresh)
        end)
        return
    else busy = false; return end
    request(method, path, body, function(data) busy = false; publish(normalize(data)) end)
end)
noctalia.setUpdateInterval(5000)
update()
