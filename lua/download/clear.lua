local Filter_Class = require "filter_class"["Filter_Class"] --过滤模块类
local Mysql_Class = require "mysql_class"["Mysql_CLass"] --数据库db类

local reqtable = Filter_Class:new() --实例化mysql类
local mysql = Mysql_Class:new(reqtable) --实例化mysql类


local err, item = mysql:rebuild_cache() --重建缓存

if err then
	ngx.say(err)
else
	ngx.say(cjson.encode(item))
end