#!./perl 

BEGIN {
    chdir 't' if -d 't';
    @INC = '../lib';
    $ENV{PERL5LIB} = '../lib';
    require './test.pl';
}

$| = 1;

plan tests => 28;

# catch "used once" warnings
use warnings;
my @warns; BEGIN { $SIG{__WARN__} = sub { push @warns, @_ }; }

my ($e, $w) = ('') x 2;

$w = q|Name "main::x" used only once: possible typo|;
%x = ();
ok( (grep { /^$w/ } @warns), "Got: $w" );

$w = q|Name "main::y" used only once: possible typo|;
$y = 3;
ok( (grep { /^$w/ } @warns), "Got: $w" );

$w = q|Name "main::z" used only once: possible typo|;
@z = ();
ok( (grep { /^$w/ } @warns), "Got: $w" );

$w = q|Name "X::x" used only once: possible typo|;
$X::x = 13;
ok( (grep { /^$w/ } @warns), "Got: $w" );

my $expected = 4;;
is( @warns, $expected, "Got $expected 'used only once' warnings" );

use vars qw($p @q %r *s &t $X::p);

# this is inside eval() to avoid creation of symbol table entries and
# to avoid "used once" warnings

eval <<'EOE';
ok( $main::{p}, '$main::{p}' );
ok( q{ARRAY},   'q{ARRAY}'   );
ok( *r{HASH},   '*r{HASH}'   );
ok( $main::{s}, '$main::{s}' );
ok( *t{CODE},   '*t{CODE}'   );
ok( $X::{p},    '$X::{p}'    );
ok( q{ARRAY},   'q{ARRAY}'   );
EOE
ok( ! $@, 'nothing in $@' );

# I don't understand this test in the original
#eval q{use vars qw(@X::y !abc); $e = ! *X::y{ARRAY} && 'not '};
#print "${e}ok 14\n";

{
    my $error = q|'!abc' is not a valid variable name|;
    local $@;
    eval q{ use vars qw(@X::y !abc); ! *X::y{ARRAY} };
    like( $@, qr/$error/, $error);
}
{
    my $error = q|Can't declare individual elements of hash or array|;
    local $@;
    eval q{ use vars qw($x[3]) };
    like( $@, qr/$error/, $error);
}
{
    no warnings;
    local $@;
    eval q{ use vars qw($!) };
    ok( ! $@, "no errors" );
}
{
    $w = q|No need to declare built-in vars|;
    eval q{ use warnings "vars"; use vars qw($!) };
    ok( (grep { /^$w/ } @warns), "Got: $w" );
}
{
    no strict 'vars';
    local $@;
    eval q{ use vars qw(@x%%) };
    ok(! $@, 'no errors' );
}

local $@;
ok( ! (! *{'x%%'}{ARRAY}), q|! *{'x%%'}{ARRAY}| );

{
    local $@;
    eval q{ $u = 3; @v = (); %w = () };
    ok(! $@, 'no errors' );
}
{
    use strict 'vars';
    local $@;
    eval q{ use vars qw(@y%%) };
    like($@, qr/'\@y%%' is not a valid variable name under strict vars/,
        'qw(@y%%)' );

    ok( ! *{'y%%'}{ARRAY}, q|*{'y%%'}{ARRAY}| );

    local $@;
    eval q{ $u = 3; @v = (); %w = () };
    my @errs = split /\n/, $@;
    is(@errs, 3, "Got 3 errors");
    ok( (grep { /^Global symbol "\$u" requires explicit package name/ } @errs),
        q|Got error message for '$u'|);
    ok( (grep { /^Global symbol "\@v" requires explicit package name/ } @errs),
        q|Got error message for '@v'|);
    ok( (grep { /^Global symbol "\%w" requires explicit package name/ } @errs),
        q|Got error message for '%w'|);
}

{
    no strict;
    local $@;
    eval q{ use strict "refs"; my $zz = "abc"; use vars qw($foo$); my $y = $$zz; };
    ok($@, 'use vars error check modifying other strictness');
}

__END__




