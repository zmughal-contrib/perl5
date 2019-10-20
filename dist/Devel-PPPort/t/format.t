################################################################################
#
#            !!!!!   Do NOT edit this file directly!   !!!!!
#
#            Edit mktests.PL and/or parts/inc/format instead.
#
#  This file was automatically generated from the definition files in the
#  parts/inc/ subdirectory by mktests.PL. To learn more about how all this
#  works, please read the F<HACKERS> file that came with this distribution.
#
################################################################################

BEGIN {
  if ($ENV{'PERL_CORE'}) {
    chdir 't' if -d 't';
    @INC = ('../lib', '../ext/Devel-PPPort/t') if -d '../lib' && -d '../ext';
    require Config; import Config;
    use vars '%Config';
    if (" $Config{'extensions'} " !~ m[ Devel/PPPort ]) {
      print "1..0 # Skip -- Perl configured without Devel::PPPort module\n";
      exit 0;
    }
  }
  else {
    unshift @INC, 't';
  }

  sub load {
    eval "use Test";
    require 'testutil.pl' if $@;
  }

  if (5) {
    load();
    plan(tests => 5);
  }
}

use Devel::PPPort;
use strict;
BEGIN { $^W = 1; }

package Devel::PPPort;
use vars '@ISA';
require DynaLoader;
@ISA = qw(DynaLoader);
bootstrap Devel::PPPort;

package main;

use Config;

if ("$]" < '5.004') {
    for (1..5) {
        skip 'skip: No newSVpvf support', 0;
    }
    exit;
}

my $num = 1.12345678901234567890;

eval { Devel::PPPort::croak_NVgf($num) };
ok($@ =~ /^1.1234567890/);

ok(Devel::PPPort::sprintf_iv(-8), 'XX_-8_XX');
ok(Devel::PPPort::sprintf_uv(15), 'XX_15_XX');

my $ivsize = $Config::Config{ivsize};
my $ivmax = ($ivsize == 4) ? '2147483647' : ($ivsize == 8) ? '9223372036854775807' : 0;
my $uvmax = ($ivsize == 4) ? '4294967295' : ($ivsize == 8) ? '18446744073709551615' : 0;
if ($ivmax == 0) {
    for (1..2) {
        skip 'skip: unknown ivsize', 0;
    }
} else {
    ok(Devel::PPPort::sprintf_ivmax(), $ivmax);
    ok(Devel::PPPort::sprintf_uvmax(), $uvmax);
}
