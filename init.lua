-- @author Alexandru Elisei &lt;alexandru.elisei@gmail.com&gt;
-- @copyright 2016 Alexandru Elisei
-- @release 1.0.0

-- Module environment
local wibox = require('wibox')
local awful = require('awful')
local os = os
local timer = timer
local table = table

local glimpse = {mt = {}}

local defaults = {
    poll_interval = 300,
    fetch_interval = 10,
    tmpdir = '/tmp',
    pydir = '/usr/share/awesome/lib/glimpse'
}

function glimpse:fetch_mail()
    -- Setting all acounts' state to fetching mail.
    for key, account in pairs(self.accounts) do
        self.accounts[key].state = 'fetching'
        os.execute('touch '..account.tmpfile..' && chmod 0600 '..account.tmpfile..' && PYTHONIOENCODING=utf8 '..self.pyfile..' '..account.conf..' &> '..account.tmpfile..' &')
    end
end

function glimpse:get_widget_text()
    local widget_text = ''

    for _, account in pairs(self.accounts) do
        widget_text = widget_text..account.shortname..': '
        if account.state == 'fetching' then
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

    self.timer = timer({timeout = self.fetch_interval})
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

function glimpse:toggle_notification()
    if self.notification and self.notification.box.visible then
        self.notification:die()
    else
        self:notify(true)
    end
end

--- Create the notification with the fetched emails from the temporary files.
-- @param all If all fetched emails should be previewed or only those from the
--   accounts with new emails or with an error.
function glimpse:notify(all)
    local notification_text = ''

    for _, account in pairs(self.accounts) do
        if all then
            notification_text = notification_text..account.content
            if account.state == 'new' then
                account.state = 'seen'
            end
        elseif account.state == 'new' then
            notification_text = notification_text..account.content
            account.state = 'seen'
        elseif account.state == 'error' then
            notification_text = notification_text..account.content
        end
    end

    if notification_text:len() > 0 then
        self.notification = naughty.notify({title = 'Glimpse', text = notification_text, timeout = 10})
    end
end

function glimpse:check_mail()

    if self.fetch_all then
        self.fetch_all = false
        self:fetch_mail()
        self:reset_timer(self.fetch_interval)
        return
    end

    local fetch_timed_out = false

    for key, account in pairs(self.accounts) do
        -- Only check accounts who are fetching the emails or had an error
        -- during a previous attempt.
        if account.state == 'fetching' or account.state == 'error' then
            local account_timed_out = false
            local f = io.open(account.tmpfile)

            if f == nil then
                account_timed_out = true
                fetch_timed_out = true
            end

            local count

            if not account_timed_out then
                count = f:read('*line')
                if count == nil then
                    f:close()
                    account_timed_out = true
                    fetch_timed_out = true
                end
            end

            if not account_timed_out then
                if string.match(count, '^[0-9]+$') then
                    count = tonumber(count)
                    self.accounts[key].count = count

                    if account.prev_count ~= count or account.state == 'error' then
                        self.accounts[key].content = '\n['..account.account..']\n'..f:read('*all')
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

    if fetch_timed_out then
        -- Retry reading the account temporary files.
        self:reset_timer(self.fetch_interval)
    else
        -- Queue polling all accounts.
        self.fetch_all = true
        self:reset_timer(self.poll_interval)
    end
end

--- Constructor for the glimpse module.
-- @param pydir The directory where the script glimpse.py is located.
--   Default: /usr/lib/awesome/lib/glimpse
-- @param tmpdir The directory where the fetched emails will be located.
--   Default: /tmp
-- @param poll_interval The interval between fetching emails, in seconds.
--   Default: 300
-- @param retry_interval The interval between checking the temporary files
--   after the command to fetch the mails has been issued, in seconds.
--   Default: 10
-- @param accounts Numerically indexed table with account information.
-- @param accounts.account Account name. Will be displayed in the notifications.
-- @param accounts.shortname Account shortname. Will be displayed in the
--   wibox.
-- @param accounts.conf Path to configuration file for the account.
local function new(args)
    local self = setmetatable({}, {__index = glimpse})

    self.poll_interval = args.poll_interval or defaults.poll_interval
    self.fetch_interval = args.fetch_interval or defaults.fetch_interval

    local homedir = os.getenv("HOME")
    local pydir = args.pydir or defaults.pydir
    pydir = pydir:gsub("^~", homedir)
    self.pyfile = pydir..'/glimpse.py'

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
    self.widget:buttons(awful.util.table.join(
        awful.button({ }, 1, function() self:toggle_notification() end),
        awful.button({}, 3, function() self:start() end),
        awful.button({}, 2, function() self:stop() end)
    ))

    return self
end

function glimpse.mt:__call(...)
    return new(...)
end

return setmetatable(glimpse, glimpse.mt)
