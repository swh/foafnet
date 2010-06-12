#!

dns-sd -B _sparqlxmpp._tcp local | sed '/^Browsing/d; /^Timestamp/d; s/.* //'
