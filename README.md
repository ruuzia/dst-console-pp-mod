# Console++

Mod for Don't Starve Together:
https://steamcommunity.com/sharedfiles/filedetails/?id=2758553790

Console++ extends the Lua command-line interface in Don't Starve Together with advanced, usable features such as multi-line console, scrollable logs, displaying of caves/master logs, and dynamic Lua word completion.

As of version 1.5.0, Console++ is organized into highly modular *feature modules*. These *feature modules* are independent and contain automated test. They can also be individually disabled and re-enabled from the mod settings. I describe most of the feature modules individually below:

### Multiline console

Provides the command console with full multi-line input support. It is stylized slightly differently from the vanilla console and is able to grow and shrink with new lines. Use Shift+Enter to create a new line. Enter is also interpreted to create a new line rather than running the command if there is an unfinished Lua do/end block or similar. However, the reason most people want the multi-line input is to easily paste in multi-line blocks of code. Up and down arrow keys move between lines.

### Dynamic Lua word completions

Provides word prediction suggestions for field names (and global variables). The feature module supports chains (ThePlayer.components.dancer.salsa.). It also currently will evaluate a function *if* it is a simple call and you're indexing the result (c_select().components.burnable.). With the client-only mod, Lua completion won't work server-side except on client-only worlds. To get Lua completion when testing on dedicated servers, install the server version of the mod.

### Scrollable Logs

The in-game console log is scrollable, try it!

### Shard Logs

Provides access to Master and Caves logs in addition to Client logs. As long as you are the one hosting the server and the files are stored locally, the shard logs can actually be retrieved with only the client-only version of the mod. Alternatively, if the server version of the mod is used, the logs can be retrieved from the server and sent to the client.

### Evaluate as Expression

No more wrapping everything in print()! This module adds behaviour similar to what can be found in the Lua REPL. Prefix your input with an equal sign "=" and it will be evaluated as an expression rather than a block. Additionally, even without the "=" it will first try to parse the command as an expression and then only evaluate as a block if it fails. Finally, the results of commands evaluated as an expression will be pretty printed nicely.

### textedit_click_to_position

Adds mouse support for text inputs. Click in the text to position the cursor.

### quiet_server_pause_messages

Minor feature: disables those pesky "Server Pause" and "Server Unpaused" messages

### use_last_remote_toggle

Minor feature: when opening the console, default the remote execute toggle (the "Local/Remote") to last execute command.

### keep_open

Minor feature: use Ctrl+Enter to evaluate the console input without closing the console. Toggle an option in mod settings to instead keep the console open with plain Enter, and use Ctrl+Enter to run and close.

### console_commands

This feature module is being considered for removal because it is kind of out of the scope of this mod. Currently provides an awesome and efficient c_revealmap() command.

### text_navigation

Text navigation features: home, end, ctrl+left, ctrl+right, ctrl+backspace, etc.

### pseudoclipboard

The game supports reading from the native clipboard but it does not support saving text to the operating system's clipboard. Pseudo-clipboard is an experimental feature which aims to make it easier to switch between editing a command within the game and editing it in a real text editor. In your `mods` folder you'll see a new file called `console_clipboard.lua` which contains instructions on how to use it: From the console, use Ctrl+C to copy the current console input into the file. To send the current file content back to the console, use Ctrl+Shift+C.

### tab_insertion

Supports insertion and deletion of "tabs" (configurable number of spaces in mod settings).

### config_screen

Run `ConsolePP.Config()` to open mod settings from anywhere without reloading.
