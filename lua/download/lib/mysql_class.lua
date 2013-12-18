module("mysql_class", package.seeall)


local mysql = require "resty.mysql"

local ERR_MYSQL_LIB = "could not open mysql library"
local ERR_MYSQL_DB = "could not open mysql database"
local ERR_MYSQL_ERROR = "mysql occur error"
local ERR_NO_ID_AND_NAME = "no id or no name"
local ERR_NOT_FOUND_ITEM = "not found item"
local ERR_NO_ITEM_ID = "no item id"
local ERR_BUILD_CACHE = 'build cache error'


Mysql_CLass = class('Mysql_CLass')

function Mysql_CLass:initialize(reqTable)
    self.host = "192.168.20.10"
    self.port = 3306
    self.database = "statis_download"
    self.user = "trmotpuser"
    self.password = "javjav"
    self.max_packet_size =  1024 * 1024

    self.max_idle_timeout = 1000*60
    self.pool_size = 50
    self.reqTable = reqTable  --获得filter类的实例

end


function Mysql_CLass:connect()
		
        local db, err = mysql:new()

        if not db then
	    ngx.log(ngx.ERR, "mysql library error " .. err) --出错记录错误日志，无法加载mysql库
            return ERR_MYSQL_LIB --返回错误code
        end
	
	self.db = db

        db:set_timeout(3000) -- 设定超时间3 sec

	local ok, err, errno, sqlstate = db:connect{ --建立数据库连接
                   host = self.host,
                   port = self.port,
                   database = self.database,
                   user = self.user,
                   password = self.password,
		   pool = self.pool_size,
                   max_packet_size = self.max_packet_size 
		}

	if not ok then --如果连接失败
	      ngx.log(ngx.ERR, "mysql not connect: " .. err) --出错记录错误日志
	      return ERR_MYSQL_DB  --返回错误code
        end
	
	return nil, db --连接成功返回ok状态码

end



function Mysql_CLass:close_conn() --关闭mysql连接封装
	 
	 local db = self.db
	 
	 local ok, err = db:set_keepalive(self.max_idle_timeout, self.pool_size) --将本链接放入连接池

	 if not ok then  --如果设置连接池出错
	    ngx.log(ngx.ERR, "mysql failed to back connect pool: " .. err) 
         end
	
end



function Mysql_CLass:query_item()

	 if self.reqTable.id == "" and self.reqTable.name == "" then	        
		return ERR_NO_ID_AND_NAME, nil
	 end

	 local is_cache = ngx.shared.down_cache:get("is_cache")

	 if is_cache == "0" then
		local err, db_tables = self:rebuild_cache()
		if err then
		   return err, nil
		end
	 end
	
	 local key
	 if self.reqTable.id ~= "" then
		key = self.reqTable.id		
	 elseif self.reqTable.name ~= "" then		
		key = self.reqTable.name		
	 end
	
	 local down_table = ngx.shared.down_cache:get(tostring(key))
	 --ngx.say(down_table)
	 if not down_table then
		return 404,ERR_NOT_FOUND_ITEM
	 end

	 local ok,err = pcall(function() 
	       down_table = cjson.decode(down_table)
	      end)

	 if not ok then
	       ngx.log(ngx.ERR, "json decode"..key.."error: "..err)
	 end

	 self.reqTable.id = down_table["id"]
	
	 return nil,down_table
	  
end


function Mysql_CLass:inset_statis() --插入一条新的点击流水
   
     local err,db = self:connect()

     if err then
        self:close_conn()
	return err,nil
     end


     if not self.reqTable.id then
        self:close_conn()
	return ERR_NO_ITEM_ID,nil
     end

     local sql_str = "INSERT INTO statis (agent, ip, downitem_id,tag,writetime) VALUES("
     ..ngx.quote_sql_str(self.reqTable.agent)..","
     ..ngx.quote_sql_str(self.reqTable.ip)..","
     ..ngx.quote_sql_str(self.reqTable.id)..","
     ..ngx.quote_sql_str(self.reqTable.tag)..","
     ..ngx.quote_sql_str(ngx.localtime())..")"
	
     local res, err, errno, sqlstate =  --插入
	db:query(sql_str)
     
     if err then
	      ngx.log(ngx.ERR, "get mysql data error: " .. err) --出错记录错误日志
	      self:close_conn()
	      return ERR_MYSQL_ERROR, nil
     end
     self:close_conn()
     return nil,"ok"

end


function Mysql_CLass:rebuild_cache() --重新创建缓存
	 
	 local err,db = self:connect()

	 if err then
	        self:close_conn()
		return err,nil
	 end
	 
	 local res, err, errno, sqlstate =  --查询 ApiServices 表
		db:query("select * from downitem where enable=1" )
	 
	 self:close_conn() -- 关闭数据库连接

	 if not res then
	      --如果ApiServices表查询出错
	      ngx.log(ngx.ERR, "get mysql data error: " .. err .. ": " .. errno .. ": ".. sqlstate .. ".") --出错记录错误日志	      
	      return ERR_MYSQL_ERROR, nil
	 end

	 ngx.shared.down_cache:flush_all()  --查到记录，重新清空缓存

	 ngx.shared.down_cache:set("is_cache", "0")  --将缓存重建标识设置为0
	 
	 for i,v in ipairs(res) do
	      
	      local ok,err = pcall(function() 
		    ngx.shared.down_cache:set(v["name"], cjson.encode(v)) --分别写入name和id缓存，方便快速查找
		    ngx.shared.down_cache:set(tostring(v["id"]), cjson.encode(v))
	      end)
	      if not ok then
		  ngx.log(ngx.ERR, "json encode"..v["name"].."error: "..err)
		  return ERR_BUILD_CACHE,nil
	      end
		
	 end
	 
	 ngx.shared.down_cache:set("is_cache", "1")	  
	 
	 return nil,res

end