#!/usr/bin/env perl
use FindBin;
use lib "$FindBin::Bin/../..";

use strict;
use warnings;

use Test::More qw(no_plan);

use Getopt::NounVerb qw(get_nv_opts);

my $testcmds = {
	local           => { h => 'commands to run locally',
		compile       => { h => 'compile the project found in cwd',
			release     => { h => 'compile for release?  default no', d => 0 },
			optimize    => { h => 'enable optimizaion flags.  default yes', d => 1 }
			},
		},
	aa              => { h => 'Absolute Automation management routines',
		'swap-server' => { h => 'Replace an existing automate server with a new one',
			old         => 'Old instance ID or name',
			new         => 'New instance ID or name',
			},
		'ssh'         => { h => 'Run an SSH command in parallel against multiple servers',
			servers     => { h => "comma-separated list of servers", x => sub { [split(',',shift) ] } },
			command     => 'Command to run',
			},
		}
	};
 
my $l1 = <<HERE;

Usage: nounverb.t NOUN VERB <OPTIONS>

  noun   description
  -----  -------------------------------------------------------------------------
  aa     Absolute Automation management routines
  local  commands to run locally
HERE

my $l2 = <<HERE;

Usage: nounverb.t aa VERB <OPTIONS>

  verb         description
  -----------  -------------------------------------------------------------------
  ssh          Run an SSH command in parallel against multiple servers
  swap-server  Replace an existing automate server with a new one
HERE

my $l3 = <<HERE;

Usage: nounverb.t aa ssh <OPTIONS>

  option   value
  -------  -----------------------------------------------------------------------
  command  Command to run
  servers  comma-separated list of servers
HERE

my $l4 = <<HERE;

Usage: nounverb.t aa ssh <OPTIONS>

ERROR: Missing required option: servers

  option   value
  -------  -----------------------------------------------------------------------
  command  Command to run
  servers  comma-separated list of servers
HERE

#--------------------------------------------------------------------------------
# positive tests
#--------------------------------------------------------------------------------
is_deeply( [ 'aa', 'ssh', { servers => [qw(s1 s2)], command => 'foo' } ], [ get_nv_opts($testcmds, [qw(aa ssh -c foo -s), 's1,s2']) ], 'standard usage with arrayref transform');
is_deeply( [ 'aa', 'ssh', { servers => [qw(s1 s2)], command => 'foo', verbose => 1} ], [ get_nv_opts($testcmds, [qw(aa ssh -c foo -v -s), 's1,s2']) ], 'standard usage with extra_opts (verbose)');

#--------------------------------------------------------------------------------
# negative tests
#--------------------------------------------------------------------------------
ok_die($l1, 'no noun nor verb', []);
ok_die($l1, 'bare help', ['help']);
ok_die($l1, 'bare --help', ['--help']);
ok_die($l1, 'unrecognized noun', ['foo']);

ok_die($l2, 'no verb', [qw(aa)]);
ok_die($l2, 'noun help', [qw(aa help)]);
ok_die($l2, 'noun --help', [qw(aa --help)]);
ok_die($l2, 'noun w/ unrecognized verb', [qw(aa foo)]);

ok_die($l3, 'noun verb help', [qw(aa ssh help)]);
ok_die($l3, 'noun verb --help', [qw(aa ssh --help)]); # Getopt::Resolved does get called here

ok_die($l4, 'missing required parameter', [qw(aa ssh)]); # and here, of course


sub ok_die {
	my ($expected, $label, $argv) = @_;
	eval { get_nv_opts($testcmds, $argv) };
	ok($@, "$label died as expected");
	is($@, $expected, "$label helptext correct");
	}
