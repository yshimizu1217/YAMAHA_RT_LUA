--[[
Access the router's WAN(LAN) and send WOL packets.

Access RT_Addr:2222
Before using, set MAC address with Yamaha command.
Using wol01-wol09 variables
for exsample "set wol01=vlan1,aa:bb:cc:11:22:33"
]]

-- start. 

tcp = rt.socket.tcp()
tcp:setoption("reuseaddr", true)
res, err = tcp:bind("*", 2222)
if not res and err then
	rt.syslog("NOTICE", err)
	os.exit(1)
end
res, err = tcp:listen()
if not res and err then
	rt.syslog("NOTICE", err)
	os.exit(1)
end

while 1 do
	local control = assert(tcp:accept())
	local raddr, rport = control:getpeername()

	control:settimeout(30)
	local ok, err = pcall(function ()
		-- get request line
		local request, err, partial = control:receive()
		if err then error(err) end
		-- get request headers
		while 1 do
			local header, err, partial = control:receive()
			if err then error(err) end
			if header == "" then
				-- end of headers
				break
			else
				-- just ignore headers
			end
		end

		if string.find(request, "GET / ") == 1 then
			local sent, err = control:send(
				"HTTP/1.0 200 OK\r\n"..
				"Connection: close\r\n"..
				"Content-Type: text/plain\r\n"..
				"\r\n"..
				"# Wake On Lan Execute\n"
			)
			if err then error(err) end

			local i
			for i = 1 , 9 do
				local wolInfo = os.getenv("wol0" .. tostring(i))
				if wolInfo ~= nil then
					local interface,macAddr = string.split(wolInfo,",")
					-- Skip checking if the value is correct --
					local cmd = "wol send " .. interface .. " " .. macAddr
					rt.command(cmd)
					
					local sent, err = control:send(
						interface .. ", " .. macAddr .. " ... done \r\n"
					)
					if err then error(err) end
				end
			end

		else
			local sent, err = control:send(
				"HTTP/1.0 404 Not Found\r\n"..
				"Connection: close\r\n"..
				"Content-Type: text/plain\r\n"..
				"\r\n"..
				"Not Found"
			)
			if err then error(err) end
		end
	end)
	if not ok then
		rt.syslog("INFO", "failed to response " .. err)
	end
	control:close()
	collectgarbage("collect")
end
