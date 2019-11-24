
#include <lua.h>
#include <lauxlib.h>
#include <sys/types.h>
#include <unistd.h>
#include <dirent.h>
#include <errno.h>
#include <string.h>
#include <signal.h>

int l_fork(lua_State *L) {
	// we don't care about our children, so we want the kernel to auto-reap them
	// this avoids zombie/defunct processes
	signal(SIGCHLD, SIG_IGN);

	pid_t newpid = fork();
	if (newpid == -1) {
		int err = errno;
		lua_pushnil(L);
		lua_pushstring(L, strerror(err));
		return 2;		
	}

	lua_pushnumber(L, newpid);
	return 1;
}

int l_closefds(lua_State *L) {
	const int excludefd = luaL_checkinteger(L, 1);

	DIR *dirp = opendir("/proc/self/fd");
	if (!dirp) {
		int err = errno;
		lua_pushnil(L);
		lua_pushstring(L, strerror(err));
		return 2;
	}

	int specialfd = dirfd(dirp);
	if (specialfd < 0) {
		int err = errno;
		lua_pushnil(L);
		lua_pushstring(L, strerror(err));
		closedir(dirp);
		return 2;
	}

	int closed = 0;
	errno = 0;
	while (!errno) {
		struct dirent * entry = readdir(dirp);
		if (!entry) break;

		char* name = entry->d_name;
		if (name[0] < '0' || name[0] > '9') continue;

		int fd = 0;
		while (name[0]) {
			fd = fd * 10 + (name[0] - '0');
			name++;
		}

		if (fd != specialfd && fd != excludefd) {
			close(fd);
			closed++;
		}
	}
	if (errno) {
		int err = errno;
		lua_pushnil(L);
		lua_pushstring(L, strerror(err));
		closedir(dirp);
		return 2;
	}

	if (closedir(dirp) != 0) {
		int err = errno;
		lua_pushnil(L);
		lua_pushstring(L, strerror(err));
		return 2;
	}

	lua_pushnumber(L, closed);
	return 1;
}

int l_closefd(lua_State *L) {
	const int fd = luaL_checkinteger(L, 1);
	if (close(fd) != 0) {
		int err = errno;
		lua_pushnil(L);
		lua_pushstring(L, strerror(err));
		return 2;		
	}
	lua_pushboolean(L, 1);
	return 1;
}

int l_setoutput(lua_State *L) {
	const int fd = luaL_checkinteger(L, 1);
	dup2(fd, STDOUT_FILENO);
	dup2(fd, STDERR_FILENO);
	return 0;
}

LUAMOD_API int luaopen_lforkshell(lua_State *L) {
	lua_newtable(L);

	lua_pushcfunction(L, l_fork);
	lua_setfield(L, -2, "fork");

	lua_pushcfunction(L, l_closefds);
	lua_setfield(L, -2, "closefds");

	lua_pushcfunction(L, l_closefd);
	lua_setfield(L, -2, "closefd");

	lua_pushcfunction(L, l_setoutput);
	lua_setfield(L, -2, "setoutput");

	return 1;
}

// ({debug.getlocal(3,2)})[2].conn.socket():getfd()
