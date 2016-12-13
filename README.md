glimpse
=======


#### Description
Glimpse is a widget for [awesome WM](https://awesomewm.org/) to periodically check for new emails.


#### Requirements
Glimpse requires the following:
- >=awesome-3.5.1 for the awesome timer API and wibox.widget.textbox()
- >=python-3.2.0 for the function ConfigParser.read_file()


#### Installation
Clone the repository
```
git clone https://github.com/alexandru-elisei/glimpse.git glimpse
```
or download the zip file (by clicking on the 'Clone or download' button) and extract it.


#### Usage
The widget works by periodically invoking the script glimpse.py with a configuration file and saving the output in a temporary file. This output is then parsed by the glimpse lua module and displayed.

You need to create a configuration file for each account. You can do that by copying and modifying the example.conf file. This file will contain the password for your email account in PLAINTEXT, so make sure nobody has access to it. You can do this by modifying the permissions on the file (chmod 0600 your_conf.conf) and make sure you lock your session each time you leave computer unsupervised.

The temporary files, one per account, are created with the default permissions of 0600 and are named .glimpse_shortname.out (notice the starting dot), where 'shortname' is the shortname for the email account.

To create the widget you need to modify the ~/.config/awesome/rc.lua configuration file. If the file doesn't exist you can copy the global configuration file from /etc/xdg/awesome/rc.lua (and create the directories, if they don't exist). If you cannot find the global configuration file at the above location you can display the files belonging to the awesome package by using your package manager. Do not modify the global configuration because each user will be able to see the fetched headers from your accounts.

To add the widget to rc.lua:
- add the statement
```lua
glimpse = require('glimpse')
```
before loading the wibox module. Before you do this you will need to  modify the package.path variable to point to the directory where glimpse.lua was copied. Assuming that the glimpse directory is located at /home/user/glimpse:
```lua
if string.find(package.path, '/home/user/glimpse/?.lua;') == nil then
    package.path = '/home/user/glimpse/?.lua;'..package.path
end
```
- instantiate the widget
```lua
email = glimpse({accounts = {{shortname = 'short', account = 'account@mail.com', conf = '~/account.conf'}}, pydir = '~/glimpse'})
```
- start the widget
```lua
email:start()
```
- optionally, attach button events to the widget on the statusbar
```lua
email.widget:buttons(awful.util.table.join(
    awful.button({ }, 1, function() email:toggle_notification() end),
    awful.button({}, 3, function() email:start() end),
    awful.button({}, 2, function() email:stop() end)
))
```
to use the left mouse button to toggle the notification, the scroll click to stop the automatic fetching of emails and the right mouse button to (re)start the widget.
- add the widget to the statusbar. Before the line right_layout:add(mytextclock) insert the following:
```lua
right_layout:add(email.widget)
```
and the widget will appear right before the clock.


#### Version
Glimpse uses [Semantic Versioning](http://semver.org/).
