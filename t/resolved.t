#!/usr/bin/env perl
use FindBin;
use lib "$FindBin::Bin/../..";
use use_thirdparty_libs;

use strict;
use warnings;

use Test::More qw(no_plan);

use Getopt::Resolved qw(get_opts);


my $testspec = {
	namespace => 'operational namespace',
	timeout   => { h => 'HTTP timeout.  Default 30 seconds', d => 30, t => 'i', x => sub { local ($_) = @_; $_ == 29 ? 'TWENNYNI!' : $_; } },
	prefix    => { h => 'Optional URL prefix', d => undef },
	queue     => { h => 'queue to which to post. Defaults to the namespace', d => sub { shift->('namespace') }, v => sub { local ($_) = @_; die("queue too short\n") unless length > 2; } },
	};

my $helptext = <<HERE;

  option     value
  ---------  ---------------------------------------------------------------------
  namespace  operational namespace
  timeout    HTTP timeout.  Default 30 seconds
  queue      queue to which to post. Defaults to the namespace
  prefix     Optional URL prefix

HERE

#--------------------------------------------------------------------------------
# positive tests
#--------------------------------------------------------------------------------
is_deeply({namespace => 'foo', queue => 'foo', timeout => 30, prefix => undef}, get_opts($testspec, [qw(-n foo)]), 'undef default value');
is_deeply({namespace => 'foo', queue => 'foo', timeout => 'TWENNYNI!', prefix => undef}, get_opts($testspec, [qw(-n foo -t 29)]), 'timeout transformed');

#--------------------------------------------------------------------------------
# negative tests
#--------------------------------------------------------------------------------
ok_die('automatically adds --help option', [qw(--help)]);
ok_die('type mismatch', [qw(-t yada)], 'ERROR: Value "yada" invalid for option timeout (number expected)');
ok_die('required opt missing', [], 'ERROR: Missing required option: namespace');
ok_die('queue name failed verifidation', [qw(-n fo)], 'ERROR: queue too short');


sub ok_die {
	my ($label, $argv, $firstline) = @_;
	$firstline &&= "\n$firstline\n";
	$firstline ||= '';
	eval { get_opts($testspec, $argv) };
	ok($@, "$label died as expected");
	is($@, $firstline . $helptext, "$label helptext correct");
	}
