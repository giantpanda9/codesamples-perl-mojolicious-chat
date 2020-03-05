#!/bin/bash
cpan Net::WebSocket::Server && cpan Config::Simple && cpan DBI
perl -MCPAN -e 'install Mojolicious'


