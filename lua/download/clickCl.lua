local Filter_Class = require "filter_class"["Filter_Class"] --过滤模块类
local Mysql_Class = require "mysql_class"["Mysql_CLass"] --数据库db类

local reqtable = Filter_Class:new() --实例化mysql类
local mysql = Mysql_Class:new(reqtable) --实例化mysql类


local err, item = mysql:query_item()

if err == 404 then
	return ngx.exit(ngx.HTTP_NOT_FOUND)
elseif err then
	return ngx.say(err)
end


local err,ok = mysql:inset_statis()

if err then
	return ngx.say(err)
end

local str = reqtable.device.." ok";
ngx.say(str)

