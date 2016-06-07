#!/usr/bin/perl -T

use strict;
use warnings;
use Config::IniFiles;
use Module::Load;
use DBI;
use IO::Select;

use lib './modules/';

$| = 1;


my $cfg = Config::IniFiles->new( -file => "/opt/billing/etc/api.conf" );

my $dbsource = $cfg->val("server", "database");
my $dbattr = {RaiseError => 1, AutoCommit => 1};

my $dbh = DBI->connect($dbsource, "", "", $dbattr);

load 'ws1c';
ws1c->init($cfg, $dbh);

my $fd = $dbh->func("getfd");
my $sel = IO::Select->new($fd);

while (1) {
	$sel->can_read;
	my $notify = $dbh->func("pg_notifies");
	if ($notify) {
		my ($relname, $pid) = @$notify;
		ws1c->event($relname);
	}
}
