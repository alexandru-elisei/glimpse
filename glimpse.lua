-- @author Alexandru Elisei &lt;alexandru.elisei@gmail.com&gt;
-- @copyright 2016 Alexandru Elisei
-- @release 0.2.0

-- Module environment
local wibox = require("wibox")
local os = os
local timer = timer
local table = table

local glimpse = {mt = {}}
local homedir = os.getenv("HOME")

local defaults = {
    poll_interval = 300,
    retry_interval = 10,
    tmpdir = homedir,
    pydir = '/usr/share/awesome/lib/glimpse/'
}

function glimpse:fetch_mail()
    -- Setting all acounts' state to fetching mail.
    for key, account in pairs(self.accounts) do
        self.accounts[key].state = 'fetching'
        os.execute('touch '..account.tmpfile..' && chmod 0600 '..account.tmpfile..' && PYTHONIOENCODING=utf8 '..self.pydir..'/glimpse.py '..account.conf..' > '..account.tmpfile..' &')
    end
end

function glimpse:get_widget_text()
    local widget_text = ''

    for _, account in pairs(self.accounts) do
        widget_text = widget_text..account.shortname..': '
        if account.state == "fetching" then
            widget_text = widget_text..'? '
        elseif account.state == 'error' then
            widget_text = widget_text..'ERR '
        else
            widget_text = widget_text..account.count..' '
        end
    end

    return widget_text
end

function glimpse:start()

    for key, account in pairs(self.accounts) do
        self.accounts[key].prev_count = 0
        self.accounts[key].count = 0
        self.accounts[key].content = '\n['..account.account..']\nFetching mail...\n'
    end

    self:fetch_mail()
    self.widget:set_text(self:get_widget_text())

    self.timer = timer({timeout = self.retry_interval})
    -- Using closures to preserve the object.
    self.timer:connect_signal('timeout', function() glimpse.check_mail(self) end)
    self.timer:start()
end

function glimpse:stop()
    self.timer:stop()
    self.timer.timeout = 0
    naughty.notify({title = 'Glimpse', text = '\nGlimpse stopped.'})
end

function glimpse:reset_timer(timeout)
    self.timer:stop()
    self.timer.timeout = timeout
    self.timer:start()
end

function glimpse:notify(all)
    local notification_text = ''

    for _, account in pairs(self.accounts) do
        if all then
            notification_text = notification_text..account.content
            account.state = 'seen'
        elseif account.state == 'new' then
            notification_text = notification_text..account.content
            account.state = 'seen'
        elseif account.state == 'error' then
            notification_text = notification_text..account.content
        end
    end

    if notification_text:len() > 0 then
        naughty.notify({title = 'Glimpse', text = notification_text, timeout = 10})
    end
end

function glimpse:check_mail()

    if self.fetch_all then
        self.fetch_all = false
        self:fetch_mail()
        self:reset_timer(self.retry_interval)
        return
    end

    local fetch_timeout = false

    for key, account in pairs(self.accounts) do
        -- Only check accounts who are fetching the emails.
        if account.state == 'fetching' then
            local account_timeout = false
            local f = io.open(account.tmpfile)

            if f == nil then
                account_timeout = true
                fetch_timeout = true
            end

            local count

            if not account_timeout then
                count = f:read('*line')
                if count == nil then
                    f:close()
                    account_timeout = true
                    fetch_timeout = true
                end
            end

            if not account_timeout then
                if string.match(count, '^[0-9]+$') then
                    count = tonumber(count)
                    self.accounts[key].count = count

                    -- Only preview new emails.
                    if count > account.prev_count then
                        self.accounts[key].content = '\n['..account.account..']\n'..f:read('*all')
                    end

                    if account.prev_count ~= count then
                        self.accounts[key].prev_count = count
                        self.accounts[key].state = 'new'
                    else
                        self.accounts[key].state = 'seen'
                    end
                else
                    self.accounts[key].content = '\n['..account.account..']\n'..f:read('*all')
                    self.accounts[key].state = 'error'
                end

                f:close()
            end
        end
    end

    self:notify()
    self.widget:set_text(self:get_widget_text())

    if fetch_timeout then
        -- Retry reading the account temporary files.
        self:reset_timer(self.retry_interval)
    else
        -- Queue polling all accounts.
        self.fetch_all = true
        self:reset_timer(self.poll_interval)
    end
end

local function new(args)
    local self = setmetatable({}, {__index = glimpse})

    self.poll_interval = args.poll_interval or defaults.poll_interval
    self.retry_interval = args.retry_interval or defaults.retry_interval

    local pydir = args.pydir or defaults.pydir
    pydir = pydir:gsub("^~", homedir)
    self.pydir = pydir

    local tmpdir = args.tmpdir or defaults.tmpdir
    tmpdir = tmpdir:gsub("^~", homedir)

    if args.accounts == nil then
        return print('E: glimpse: error creating object: no accounts specified')
    end
    self.accounts = {}

    for _, account in pairs(args.accounts) do
        local new_account = {}
        if account.account == nil then
            return print('E: glimpse: error creating object: no account specified')
        end
        new_account.account = account.account

        if account.shortname == nil then
            return print('E: glimpse: error creating object: no shortname specified')
        end
        new_account.shortname = account.shortname

        if account.conf == nil then
            return print('E: glimpse: error creating object: no configuration file specified')
        end
        new_account.conf = account.conf
        new_account.tmpfile = tmpdir..'/.glimpse_'..new_account.shortname..'.out'
        table.insert(self.accounts, new_account)
    end

    self.widget = wibox.widget.textbox()

    return self
end

function glimpse.mt:__call(...)
    return new(...)
end

return setmetatable(glimpse, glimpse.mt)
