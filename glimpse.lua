-- @author Alexandru Elisei &lt;alexandru.elisei@gmail.com&gt;
-- @copyright 2016 Alexandru Elisei
-- @release 0.1.0

-- Module environment
local wibox = require("wibox")
local os = os
local timer = timer

local glimpse = {mt = {}}

local homedir = os.getenv("HOME")

local defaults = {
    poll_interval = 300,
    retry_interval = 5,
    tmpdir = homedir,
    pydir = '/usr/share/awesome/lib'
}

function glimpse:start()
    self.prev_count = 0
    self.count = 0

    self.widget:set_text(self.shortname .. ': ? ')
    self.content = '\nConnecting with email server...'

    os.execute(self.pydir..'/glimpse.py '..self.conf..' > '..self.tmpfile..' &')

    self.timer = timer({timeout = retry_timemout})
    -- Using closures to preserve the object.
    self.timer:connect_signal("timeout", function() glimpse.check_mail(self) end)
    self.timer:start()
end

function glimpse:reset_timer(timeout)
    self.timer:stop()
    self.timer.timeout = timeout
    self.timer:start()
end

function glimpse:check_mail()
    local f = io.open(self.tmpfile)
    if f == nil then
        self:reset_timer(self.retry_interval)
        return
    end

    self.count = f:read('*line')
    if self.count == nil then
        f:close()
        self:reset_timer(self.retry_interval)
        return
    end

    if string.match(self.count, '^[0-9]+$') then
        self.count = tonumber(self.count)

        -- Only preview new emails.
        if self.count > self.prev_count then
            self.content = '\n['..self.account..']\n'..f:read('*all')
            naughty.notify({title = 'Email', text = self.content, timeout = 10})
        end

        if self.count ~= self.prev_count then
            self.prev_count = self.count
        end
    else
        -- Preview errors.
        self.content = '\n['..self.account..']\n'..f:read('*all')
        naughty.notify({title = 'Email', text = self.content, timeout = 10})
    end

    f:close()

    self.widget:set_text(self.shortname..': ' .. tostring(self.count))
    os.execute(self.pydir..'/glimpse.py '..self.conf..' > '..self.tmpfile..' &')

    self.timer:stop()
    self.timer.timeout = self.poll_interval
    self.timer:start()
end

local function test()
    check_mail()
end

local function new(args)
    local self = setmetatable({}, {__index = glimpse})

    self.poll_interval = args.poll_interval or defaults.poll_interval
    self.retry_interval = args.retry_interval or defaults.retry_interval

    local pydir = args.pydir or defaults.pydir
    pydir = pydir:gsub("^~", homedir)
    self.pydir = pydir

    if args.account == nil then
        return print('E: glimpse: error creating object: no accounts specified')
    end
    self.account = args.account

    if args.shortname == nil then
        return print('E: glimpse: error creating object: no account shortname specified')
    end
    self.shortname = args.shortname

    if args.conf == nil then
        return print('E: glimpse: error creating object: no configuration file specified')
    end
    self.conf = args.conf

    local tmpdir = args.tmpdir or defaults.tmpdir
    tmpdir = tmpdir:gsub("^~", homedir)
    self.tmpfile = tmpdir..'/.'..self.shortname..'.out'

    self.widget = wibox.widget.textbox()

    return self
end

function glimpse.mt:__call(...)
    return new(...)
end

return setmetatable(glimpse, glimpse.mt)
