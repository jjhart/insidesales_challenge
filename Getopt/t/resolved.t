#!/usr/bin/env perl
use FindBin;
use lib "$FindBin::Bin/../..";

use strict;
use warnings;

use Test::More qw(no_plan);

use Getopt::Resolved qw(get_opts resolve_opts);

#--------------------------------------------------------------------------------
# resolve_opts
#--------------------------------------------------------------------------------
my $d = {
	foo => { h => '', d => sub { join(',', sort((shift)->())); } }
	};
my $o = {
	yada => 'a',
	yo   => 'b'
	};
is_deeply({ foo => 'foo,yada,yo', yada => 'a', yo => 'b' }, resolve_opts($d, $o));

#--------------------------------------------------------------------------------
# get_opts
#--------------------------------------------------------------------------------


my $testspec = {
	namespace => 'operational namespace',
	timeout   => { h => 'HTTP timeout.  Default 30 seconds', d => 30, t => 'i', x => sub { local ($_) = @_; $_ == 29 ? 'TWENNYNI!' : $_; } },
	prefix    => { h => 'Optional URL prefix', d => undef },
	queue     => { h => 'queue to which to post. Defaults to the namespace', d => sub { shift->('namespace') }, v => sub { local ($_) = @_; die("queue too short\n") unless length > 2; } },
	fqqn      => { h => 'Fully qualified queue name (namespace + queue)', d => sub { join('-',shift->('namespace','queue')) }, v => sub { die('wut') unless $_[1]->('timeout') } }
	};

my $helptext = <<HERE;

  option     value
  ---------  ---------------------------------------------------------------------
  fqqn       Fully qualified queue name (namespace + queue)
  namespace  operational namespace
  prefix     Optional URL prefix
  queue      queue to which to post. Defaults to the namespace
  timeout    HTTP timeout.  Default 30 seconds

HERE

#--------------------------------------------------------------------------------
# positive tests
#--------------------------------------------------------------------------------
is_deeply({namespace => 'foo', queue => 'foo', fqqn => 'foo-foo', timeout => 30, prefix => undef}, get_opts($testspec, [qw(-n foo)]), 'undef default value');
is_deeply({namespace => 'foo', queue => 'foo', fqqn => 'foo-foo', timeout => 30, prefix => undef, verbose => 1}, get_opts($testspec, [qw(-n foo -v)]), 'verbose flag added');
is_deeply({namespace => 'foo', queue => 'foo', fqqn => 'foo-foo', timeout => 'TWENNYNI!', prefix => undef}, get_opts($testspec, [qw(-n foo -t 29)]), 'timeout transformed');

#--------------------------------------------------------------------------------
# negative tests
#--------------------------------------------------------------------------------
ok_die('automatically adds --help option', [qw(--help)]);
ok_die('type mismatch', [qw(-t yada)], 'ERROR: Value "yada" invalid for option timeout (number expected)');
ok_die('required opt missing', [], 'ERROR: Missing required option: namespace');
ok_die('queue name failed verifidation', [qw(-n fo)], 'ERROR: queue too short');

# turn off EXTRA_OPTS, get error when -v *or* -h present
my @tmp = @Getopt::Resolved::EXTRA_OPTS;
@Getopt::Resolved::EXTRA_OPTS = ();
ok_die('extra_opts removed = verbose not supported', [qw(-n foo -verbose)], 'ERROR: Unknown option: verbose');
ok_die('extra_opts removed = verbose not supported', [qw(-n foo -v)], 'ERROR: Unknown option: v');
ok_die('extra_opts removed = help not supported', [qw(-n foo -h)], 'ERROR: Unknown option: h');
@Getopt::Resolved::EXTRA_OPTS = @tmp;


sub ok_die {
	my ($label, $argv, $firstline) = @_;
	$firstline &&= "\n$firstline\n";
	$firstline ||= '';
	eval { get_opts($testspec, $argv) };
	ok($@, "$label died as expected");
	is($@, $firstline . $helptext, "$label helptext correct");
	}
