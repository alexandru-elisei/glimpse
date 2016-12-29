#!/bin/env python3

import sys
import imaplib
import email
from email.header import decode_header, make_header
import configparser
import argparse
import itertools

def exit(text):
    ERR = 'ERR\n'
    raise SystemExit(ERR + text)

def main(account):

    config = configparser.ConfigParser()
    try:
        with open(account, 'r') as lines:
            lines = itertools.chain(('[top]\n',), lines)
            config.read_file(lines)
    except OSError:
        exit('Cannot read the configuration file.')

    conf = config['top']

    host = conf.get('host', None)
    if host is None:
        exit('Host not found.')

    port = int(conf.get('port', imaplib.IMAP4_SSL_PORT))
    try:
        M = imaplib.IMAP4_SSL(host, port)
    except Exception as e:
        exit('Error connecting to ' + host +': ' + str(e) + '.')

    user = conf.get('user', None)
    if user is None:
        exit('User configuration not found.')

    password = conf.get('password', None)
    if password is None:
        exit('Password configuration not found.')

    try:
        status, msg = M.login(user, password)
    except Exception as e:
        exit('Error during ' + user + ' login: ' + str(e) + '.')

    if status != 'OK':
        exit('Error during ' + user + ' login: ' + msg.decode('ascii') + '.')

    mailbox = conf.get('mailbox', 'INBOX')
    status, msg = M.select(mailbox, True)
    if status != 'OK':
        msg = msg[0].decode()
        exit('Cannot select mailbox: ' + msg + '.')

    status, msg = M.status(mailbox, '(UNSEEN)')
    if status != 'OK':
        msg = msg[0].decode()
        exit('Cannot get UNSEEN status: ' + msg + '.')

    unseen = int(msg[0].decode().split()[2].rstrip(')'))

    status, email_ids = M.search(None, '(UNSEEN)')
    if status != 'OK':
        exit('Cannot search UNSEEN email in ' + mailbox + '.')
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
            exit('Cannot fetch email: ' + msg + '.')

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
    argparser = argparse.ArgumentParser(description='Fetch and display emails for the account defined in ACCOUNT.',
            usage='glimpse.py ACCOUNT')
    argparser.add_argument('account', metavar='ACCOUNT',
            help='The account configuration file.')
    args = argparser.parse_args()

    main(args.account)
