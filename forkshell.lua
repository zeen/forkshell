
local _ENV = _G;

-- find C lib relative to lua file
local libfilename = "lforkshell.so";
local libfunction = "luaopen_lforkshell";
local libpath = (debug.getinfo(function()end).source:gsub("^@", ""):gsub("[^/]+$", libfilename));
local f = assert(package.loadlib(libpath, libfunction));
local lforkshell = assert(f());

local function get_session()
	for i=1,100 do
		local info = debug.getinfo(i);
		if not info then return nil; end

		if info.name == nil and info.source:match("events%.lua$") then
			for j=1,100 do
				local key, val = debug.getlocal(i, j);
				if not key then return nil; end

				if key == "event_data" then
					return val.origin;
				end
			end
		end
	end
end

local function output(...)
	local n = select("#", ...);
	if n > 0 then
		if n > 1 then
			print(...)
		else
			local t = ...;
			if type(t) == "table" and not(getmetatable(t) and getmetatable(t).__tostring) then
				if next(t) == nil then
					print(tostring(t).." = {}");
				else
					print(tostring(t).." = {");
					local n = 0;
					local limit = 20;
					for k,v in pairs(t) do
						n = n + 1;
						if n <= limit then
							local ks = type(k) == "string" and ("%q"):format(k) or "["..tostring(k).."]";
							print(("  %s = %s"):format(ks, type(v)));
						end
					end
					if n > limit then
						print("  ... "..(n - limit).." more items ...");
					end
					print("}")
				end
			elseif type(t) == "function" then
				print(t);
				for i=1,math.huge do
					local k,v = debug.getupvalue(t, i);
					if not k then break; end
					print(("  [%d] %s = %s"):format(i, k, type(v)));
				end
			else
				print(...);
			end
		end
	end
end

local envload = require "util.envload".envload;
local env = setmetatable({}, { __index = _G });
local function process_line(socket, line)
	local chunkname = "=console";
	-- local env = _G; -- (useglobalenv and redirect_output(_G, session)) or session.env or nil
	local chunk, err = envload("return "..line, chunkname, env);
	if not chunk then
		chunk, err = envload(line, chunkname, env);
		if not chunk then
			-- err = err:gsub("^%[string .-%]:%d+: ", "");
			-- err = err:gsub("^:%d+: ", "");
			-- err = err:gsub("'<eof>'", "the end of the line");
			-- print("Sorry, I couldn't understand that... "..err);
			print(err);
			return;
		end
	end

	local taskok, message = xpcall(function() output(chunk()); end, debug.traceback);
	if not taskok then
		print(message);
	end

	-- if not message then
	-- 	print("Result: "..tostring(taskok));
	-- 	return;
	-- elseif (not taskok) and message then
	-- 	print("Command completed with a problem");
	-- 	print("Message: "..tostring(message));
	-- 	return;
	-- end

	-- print("OK: "..tostring(message));
end

local function forget_pidfile()
	local modulemanager = require("core.modulemanager");
	local data = modulemanager.get_module("*", "posix").module.event_handlers.data;
	local remove_pidfile_func = next(data[next(data)]["server-stopped"]);
	remove_pidfile_func.pidfile_handle = nil;
end

local function do_child(fd, socket)
	-- close all file descriptors except for our telnet client
	lforkshell.closefds(fd);
	-- forget the pid file, this child doesn't own it
	forget_pidfile();
	-- blocking mode!
	socket:settimeout(nil);
	-- point stdout and stderr to our telnet client
	lforkshell.setoutput(fd);
	-- point prosody logging to our telnet client
	local logger = require "util.logger";
	logger.reset();
	logger.add_simple_sink(function(name, level, message) print(("[%s] %s: %s"):format(level, name, message)); end);

	-- paint oomkiller target on our process
	local oom_score_adj, err = io.open("/proc/self/oom_score_adj", "w");
	if oom_score_adj then
		local OOM_SCORE_ADJ_MAX = "1000";
		oom_score_adj:write(OOM_SCORE_ADJ_MAX);
		oom_score_adj:close();
	else
		print("[warn] unable to set oom_score_adj in forked process: "..tostring(err));
	end

	print("\n>>> Forked Prosody Shell <<<");

	-- local runner = coroutine.wrap(function()
	-- 	while true do
	-- 		process_line(coroutine.yield());
	-- 	end
	-- end);
	-- runner();

	while true do
		socket:send("> ");
		local data, err = socket:receive("*l");
		if not data then os.exit(not(err) and true or false); end

		if data == "quit" or data == "q" or data == "exit" or data == "bye" or data == "\004" then os.exit(true); end

		-- runner(socket, data);
		process_line(socket, data);
	end
end

local function do_fork()
	local session = get_session();
	local conn = session.conn;

	local socket;
	local server_event = false;

	if conn.conn then -- server_event
		socket = conn.conn;
		server_event = true;
	elseif conn.socket then -- server_select
		socket = conn.socket();
	else
		error("can't find socket");
	end

	local fd = socket:getfd();

	local child = assert(lforkshell.fork());
	if child ~= 0 then
		-- parent process
		if not server_event then
			-- server_event really does not like this, but server_select needs it
			lforkshell.closefd(fd);
		end
		session.disconnect();
	else
		-- child process
		local success, err = pcall(do_child, fd, socket)
		if not success then
			socket:send("error: "..tostring(err).."\n");
			os.exit(false);
		end
	end
end

do_fork();
