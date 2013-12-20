module("filter_class", package.seeall)

string.split = function(s, delimiter)
    result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return result;
end

Filter_Class = class('Filter_Class')

--构造函数
function Filter_Class:initialize()
    self.agent = ngx.req.get_headers()["User-Agent"] or "" --获取用户agent
    local xff = ngx.req.get_headers()["X-Forwarded-For"]
    if xff then
	xff = string.split(xff, ',')[1]
    end
    local args = ngx.req.get_uri_args()
    self.name = ngx.unescape_uri(args["name"] or "")  --获取用户参数name
    self.id = args["id"] or ""       --获取用户参数id
    self.ip =  xff or ngx.var.remote_addr or ""                --获取ip地址
    self.tag = ngx.unescape_uri(args["tag"] or "")     --获取特殊标识
    self:getDevice()

end


function Filter_Class:getDevice()
    local agent = self.agent
    agent = string.lower(agent);
    
    self.device = "pc";
    if string.find(agent, "iphone") or string.find(agent, "ipad") or string.find(agent, "ipod") or string.find(agent, "ios") then
	self.device = "ios"
    elseif  string.find(agent, "android") then
	self.device = "android"
    end


end