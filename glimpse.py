#!/bin/env python3

import imaplib
import email
from email.header import decode_header, make_header
import sys
import configparser
import itertools

ERR = 'ERR\n'

def main(config_file):

    global ERR

    config = configparser.ConfigParser()
    try:
        with open(config_file, 'r') as lines:
            lines = itertools.chain(('[top]\n',), lines)
            config.read_file(lines)
    except OSError:
        print(ERR + 'Cannot read the configuration file.')
        return

    conf = config['top']

    host = conf.get('host', None)
    if host is None:
        print(ERR + 'Host configuration not found.')
        return

    port = int(conf.get('port', imaplib.IMAP4_SSL_PORT))
    try:
        M = imaplib.IMAP4_SSL(host, port)
    except Exception as e:
        print(ERR + 'Error connecting to ' + host +': ' + str(e) + '.')
        return

    user = conf.get('user', None)
    if user is None:
        print(ERR + 'User configuration not found.')
        return

    password = conf.get('password', None)
    if password is None:
        print(ERR + 'Password configuration not found.')
        return

    try:
        status, msg = M.login(user, password)
    except Exception as e:
        print(ERR + 'Error during ' + user + ' login: ' + str(e) + '.')
        return

    if status != 'OK':
        print(ERR + 'Error during ' + user + ' login: ' + msg + '.')
        return

    mailbox = conf.get('mailbox', 'INBOX')
    status, msg = M.select(mailbox)
    if status != 'OK':
        msg = msg[0].decode()
        print(ERR + 'Cannot select mailbox: ' + msg + '.')
        return

    status, msg = M.status(mailbox, '(UNSEEN)')
    if status != 'OK':
        msg = msg[0].decode()
        print(ERR + 'Cannot get UNSEEN status: ' + msg + '.')
        return

    unseen = int(msg[0].decode().split()[2].rstrip(')'))

    status, email_ids = M.search(None, '(UNSEEN)')
    if status != 'OK':
        print(ERR + 'Cannot search UNSEEN email in ' + mailbox + '.')
        return
    email_ids = email_ids[0].split()

    preview_count = unseen
    preview = int(conf.get('preview', 0))
    if preview != 0 and preview < preview_count:
        preview_count = preview

    return_string = str(unseen) + '\n'
    for i in range(preview_count):

        last_email_id = email_ids[-i - 1]
        status, data = M.fetch(last_email_id, '(RFC822)')
        if status != 'OK':
            msg = msg[0].decode()
            print(ERR + 'Cannot fetch email: ' + msg + '.')
            return

        # Removing the 'Seen' flag, we have only previewed the headers.
        M.store(last_email_id, '-FLAGS', '\\Seen')

        raw_email = data[0][1]
        email_msg = email.message_from_bytes(raw_email)

        from_header = email_msg.get('From')
        return_string += 'From:    ' + str(make_header(decode_header(from_header))) + '\n'
        subject_header = email_msg.get('Subject')

        return_string += 'Subject: ' + str(make_header(decode_header(subject_header))) + '\n'
        return_string += '\n'

    M.close()
    M.logout()

    # Removing the last newline.
    return_string = return_string[:-1]
    # Adding '...' if there are more unread email than those previewed.
    if preview_count < unseen:
        return_string += '...\n'

    print(return_string, end='')

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(ERR + 'No configuration file.')
        sys.exit(1)

    main(sys.argv[1])
