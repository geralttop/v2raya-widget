local path = arg[1] or 'projects/2026/v2raya-widget'
local state, watchers, calls, responses = {}, {}, {}, {}
local token = 'test-token'
local fixture = {running = true, touch = {servers = {{id = 1, _type = 'server', name = 'A'}}, subscriptions = {
    {id = 1, remarks = 'Test', servers = {{id = 1, _type = 'subscriptionServer', name = 'B'}}}},
    connectedServer = {{id = 1, sub = 0, _type = 'subscriptionServer', outbound = 'proxy'}}}}
noctalia = {
    state = {get = function(k) return state[k] end, set = function(k,v) state[k]=v; if watchers[k] then watchers[k](v) end end,
        watch = function(k,f) watchers[k]=f end},
    pluginDataDir = function() return '/test' end, readFile = function() return token end,
    setUpdateInterval = function() end,
    json = {encode = function(v) return v end, decode = function(v) return v end},
    http = function(req, cb)
        table.insert(calls, req)
        cb(table.remove(responses,1) or {ok=true,status=200,body={code='SUCCESS',data=fixture}})
        return true
    end,
}
dofile(path .. '/service.luau')
assert(state['vpn.status'].current == 'B')
assert(#state['vpn.status'].servers == 2)
assert(state['vpn.status'].servers[2].ref.sub == 0)
noctalia.state.set('vpn.command', {action='stop'})
assert(calls[#calls].method == 'DELETE' and calls[#calls].url:match('/v2ray$'))
noctalia.state.set('vpn.command', {action='select',name='B',ref={id=1,sub=0,_type='subscriptionServer'}})
assert(calls[#calls-1].method == 'PUT' and calls[#calls-1].body.touches[1].sub == 0)
local before = #calls
noctalia.state.set('vpn.command', {action='select',name='old',ref={id=1,sub=0,_type='subscriptionServer'}})
assert(#calls == before+1 and state['vpn.status'].error)
responses = {{ok=false,status=401,body={code='UNAUTHORIZED'}}}
update(); assert(state['vpn.status'].auth == false)
token=nil; before=#calls; update(); assert(#calls == before and state['vpn.status'].auth == false)
token='test-token'
fixture.touch.connectedServer = {{id=1,sub=0,_type='server',outbound='proxy'}, {id=1,sub=0,_type='subscriptionServer',outbound='proxy',selected=true}}
update(); assert(state['vpn.status'].current == 'B')
print('OK: normalization, subscription IDs, stop, atomic selection, stale selection, expired/missing token')
