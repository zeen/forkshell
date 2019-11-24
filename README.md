# forkshell

Fork a running Prosody, giving you a Lua REPL to modify and inspect a Prosody instance without impacting the original.

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
