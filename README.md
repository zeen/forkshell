# forkshell

Sometimes you need to debug applications in production, and it's helpful to have a REPL available. But this requires care, and you need to stay away from destructive operations.

forkshell is a tool made for [Prosody](https://prosody.im), that gives you a Lua REPL in a forked process, so you can modify and inspect without impacting the original process.

## Usage

1. Clone this repo
2. Run `make`
3. Connect to Prosody's telnet console
4. Run the following in the telnet console:

```lua
>dofile("/path/to/forkshell.lua")
```

The telnet console will now be connected to a forked Prosody, fully independent from the original Prosody. All file descriptors would be closed. stdin, stderr and loggingmanager would be connected to the telnet console.

Also includes quality of life pretty-printing of table fields and function upvalues.

## Compatibility

* Targeting Linux
* Targeting Lua 5.2
* Tested with Prosody 0.11, should work with trunk, likely won't work with older versions
* Tested with server_select, server_event and server_epoll networking backends for Prosody
* Tested with Ubuntu 18.04
