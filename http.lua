local http_executing = false
local http_requests = {}

local function doHttpGet()
    local request = http_requests[1]
    local url = request[1]
    local callback = request[2]
    table.remove(http_requests, 1)
    http.get(url, 
        nil, 
        function(s,b)
            if #http_requests == 0 then
                http_executing = false
            else
                node.task.post(doHttpGet)
            end
            if callback then
                callback(s,b)
            end
        end)
end

function httpGet(url, callback)
    -- PUTAIN lua commence a compter a 1 c'est quoi ce language de merde
    http_requests[ #http_requests + 1 ] = {url, callback}
    if(http_executing) then
        return        
    else
        http_executing = true
        doHttpGet()
    end
end


