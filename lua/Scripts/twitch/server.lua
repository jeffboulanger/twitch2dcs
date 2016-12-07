local base = _G

package.path  = package.path..";.\\LuaSocket\\?.lua;"..'.\\Scripts\\?.lua;'.. '.\\Scripts\\UI\\?.lua;'
package.cpath = package.cpath..";.\\LuaSocket\\?.dll;"

local require       = base.require
local table         = base.table
local string        = base.string
local math          = base.math
local assert        = base.assert
local pairs         = base.pairs
local ipairs        = base.ipairs

local socket        = require("socket")
local tracer        = require("twitch.tracer")

local Server = {
    commandHandlers = {}
}

function Server:new(hostAddress, port)
    local self = {}
      
    setmetatable(self, Server)

    self.__index = self        
    self.connection = socket.tcp()
    self.hostAddress = hostAddress
    self.port = port

    return self 
end

function Server:connect(username, oauthToken, caps, timeout)
    local ip = socket.dns.toip(self.hostAddress)
    local success = assert(Server.connection:connect(ip, self.port))
    
    if not success then
        tracer.default:warn("Unable to connect to "..self.hostAddress.."["..ip.."]:"..self.port)
    else
        tracer.default:info("Conncted to "..self.hostAddress.."["..ip.."]:"..self.port)
       
        self.connection:settimeout(timeout)  
        
        self:send("CAP REQ : "..table.concat(caps, " "))
        self:send("PASS "..oauthToken)
        self:send("NICK "..username)
        self:send("JOIN #"..username)
    end
end

function Server:send(data)
    local count, err = self.connection:send(data.."\r\n")
    if err then
        tracer.default:error("DCS -> Twitch: "..err)
    else    
        tracer.default:info("DCS -> Twitch: "..data)
    end
end

function Server:receive()
    local buffer, err
    repeat
        buffer, err = self.connection:receive("*l")
        if not err then
            tracer.default:info("DCS <- Twitch: "..buffer)
            if buffer ~= nil then                 
                if string.sub(buffer,1,4) == "PING" then
                    self:send(string.gsub(buffer,"PING","PONG",1))
                else    
                    local prefix, cmd, param = string.match(buffer, "^:([^ ]+) ([^ ]+)(.*)$")
                    
                    param = string.sub(param,2)

                    local param1, param2 = string.match(param,"^([^:]+) :(.*)$")
                    local user, userhost = string.match(prefix,"^([^!]+)!(.*)$")

                    if cmd == "376" then
                        twitch.send("JOIN #"..twitch.config.username)
                    end

                    local handlers = self.commandHandlers[cmd]

                    if param ~= nil and handlers ~= nil then
                        for i, handler in ipairs(handlers) do
                            handler({
                                prefix = prefix, 
                                user = user, 
                                userhost = userhost, 
                                param1 = param1, 
                                param2 = param2
                            })
                        end
                    end
                end
            end
        elseif err ~= "timeout" then
            tracer.default:error(err)
        end
    until err
end

function Server:addCommandHandler(cmd, handler)
    if not self.commandHandlers[cmd] then 
        self.commandHandlers[cmd] = {}
    end

    table.insert(self.commandHandlers[cmd], handler)
end

function Server:removeCommandHandler(cmd, handler)
    if not self.commandHandlers[cmd] then 
        return
    end

    table.remove(self.commandHandlers[cmd], handler)
end

return Server