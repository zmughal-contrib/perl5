use strict;
use warnings;

# This file tests interactions with locale and threads

BEGIN {
    chdir 't' if -d 't';
    require './test.pl';
    set_up_inc('../lib');
    require './loc_tools.pl';
    skip_all("No locales") unless locales_enabled();
    skip_all_without_config('useithreads');
    $| = 1;
    eval { require POSIX; POSIX->import(qw(errno_h locale_h  unistd_h )) };
    if ($@) {
	skip_all("could not load the POSIX module"); # running minitest?
    }
}

use Time::HiRes qw(time usleep);

my $thread_count = 5;
my $iterations = 1;
my $max_result_length = 10000;

# reset the locale environment
local @ENV{'LANG', (grep /^LC_/, keys %ENV)};

SKIP: { # perl #127708
    my @locales = grep { $_ !~ / ^ C \b | POSIX /x } find_locales('LC_MESSAGES');
    skip("No valid locale to test with", 1) unless @locales;

    local $ENV{LC_MESSAGES} = $locales[0];

    # We're going to try with all possible error numbers on this platform
    my $error_count = keys(%!) + 1;

    print fresh_perl("
        use threads;
        use strict;
        use warnings;

        my \$errnum = 1;

        my \@threads = map +threads->create(sub {
            sleep 0.1;

            for (1..5_000) {
                \$errnum = (\$errnum + 1) % $error_count;
                \$! = \$errnum;

                # no-op to trigger stringification
                next if \"\$!\" eq \"\";
            }
        }), (0..1);
        \$_->join for splice \@threads;",
    {}
    );

    pass("Didn't segfault");
}

sub C_first ()
{
    $a eq 'C' ? -1 : $b eq 'C' ? 1 : $a cmp $b;
}

# December 18, 1987
my $strftime_args = "'%c', 0, 0, , 12, 18, 11, 87";

my $has_lc_all = 0;
my %tests_prep;

use Data::Dumper;
$Data::Dumper::Sortkeys=1;
$Data::Dumper::Useqq = 1;
$Data::Dumper::Deepcopy = 1;

sub add_trials($$;$)
{
    my $category_name = shift;
    my $op = shift;
    my $locale_pattern = shift // "";

    my $category_number = eval "&POSIX::$category_name";
    die "$@" if $@;

    my %results;
    my %seen;
    foreach my $locale (sort C_first find_locales($category_name)) {
        next if $locale_pattern && $locale !~ /$locale_pattern/;

        use locale;
        next unless setlocale($category_number, $locale);

        my $result = eval $op;
        die "$category_name: '$op': $@" if $@;
        #$result = "" if $locale eq 'C' && ! defined $result;
        next unless defined $result;
        if (length $result > $max_result_length) {
            diag("For $locale, '$op', result is too long; skipped");
            next;
        }

        if ($seen{$result}++) {
            push $tests_prep{$category_name}{duplicate_results}{$op}->@*, [ $locale, $result ];
        }
        else {
            $tests_prep{$category_name}{$locale}{$op} = $result;
        }
    }
}

my $max_messages = 10;
my %msg_catalog;
foreach my $error (sort keys %!) {
    my $number = eval "Errno::$error";
    $! = $number;
    my $description = "$!";
    next unless "$description";
    $msg_catalog{$number} = quotemeta "$description";
}
my $msg_catalog = join ',', sort { $a <=> $b } keys %msg_catalog;

my $get_messages_catalog = <<EOT;
EOT

my $langinfo_LC_CTYPE = <<EOT;
use I18N::Langinfo qw(langinfo CODESET);
no warnings 'uninitialized';
join "|",  map { langinfo(\$_) } CODESET;
EOT

my $langinfo_LC_MESSAGES = <<EOT;
use I18N::Langinfo qw(langinfo YESSTR NOSTR YESEXPR NOEXPR);
no warnings 'uninitialized';
join ",",  map { langinfo(\$_) } YESSTR, NOSTR, YESEXPR, NOEXPR;
EOT

my $langinfo_LC_MONETARY = <<EOT;
use I18N::Langinfo qw(langinfo CRNCYSTR);
no warnings 'uninitialized';
join "|",  map { langinfo(\$_) } CRNCYSTR;
EOT

my $langinfo_LC_NUMERIC = <<EOT;
use I18N::Langinfo qw(langinfo RADIXCHAR THOUSEP);
 
no warnings 'uninitialized';
join "|",  map { langinfo(\$_) } RADIXCHAR; #, THOUSEP;
EOT

my $langinfo_LC_TIME = <<EOT;
use I18N::Langinfo qw(langinfo 
                      ABDAY_1 ABDAY_2 ABDAY_3 ABDAY_4 ABDAY_5 ABDAY_6 ABDAY_7
                      ABMON_1 ABMON_2 ABMON_3 ABMON_4 ABMON_5 ABMON_6
                      ABMON_7 ABMON_8 ABMON_9 ABMON_10 ABMON_11 ABMON_12
                      DAY_1 DAY_2 DAY_3 DAY_4 DAY_5 DAY_6 DAY_7
                      MON_1 MON_2 MON_3 MON_4 MON_5 MON_6
                      MON_7 MON_8 MON_9 MON_10 MON_11 MON_12
                      D_FMT D_T_FMT T_FMT
                     );

no warnings 'uninitialized';
join "|",  map { langinfo(\$_) } 
                      ABDAY_1,ABDAY_2,ABDAY_3,ABDAY_4,ABDAY_5,ABDAY_6,ABDAY_7,
                      ABMON_1,ABMON_2,ABMON_3,ABMON_4,ABMON_5,ABMON_6,
                      ABMON_7,ABMON_8,ABMON_9,ABMON_10,ABMON_11,ABMON_12,
                      DAY_1,DAY_2,DAY_3,DAY_4,DAY_5,DAY_6,DAY_7,
                      MON_1,MON_2,MON_3,MON_4,MON_5,MON_6,
                      MON_7,MON_8,MON_9,MON_10,MON_11,MON_12,
                      D_FMT,D_T_FMT,T_FMT;
EOT

my $case_insensitive_matching_test = <<'EOT';
#use re qw(Debug ALL);
my $uc = join "", map { CORE::uc chr } (0..255);
my $fc = quotemeta CORE::fc $uc;
$uc =~ / \A $fc \z /xi;
EOT

foreach my $category (valid_locale_categories()) {
        #print STDERR __FILE__, ": ", __LINE__, ": $category\n"; 
        #XXX we don't currently test this
    if ($category eq 'LC_ALL') {
        $has_lc_all = 1;
        next;
    }

    if ($category eq 'LC_COLLATE') {
        add_trials('LC_COLLATE', 'quotemeta join "", sort reverse map { chr } (1..255)');
        #use re qw(Debug ALL);
        my $english = qr/ ^ en_ /x;
        no re;
        add_trials('LC_COLLATE', '"a" lt "B"', $english);
        add_trials('LC_COLLATE', 'my $a = "a"; my $b = "B"; POSIX::strcoll($a, $b) < 0;', $english);
        add_trials('LC_COLLATE', 'my $string = quotemeta join "", map { chr } (1..255); POSIX::strxfrm($string)');
        next;
    }

    if ($category eq 'LC_CTYPE') {
        add_trials('LC_CTYPE', 'quotemeta join "", map { lc chr } (0..255)');
        add_trials('LC_CTYPE', 'quotemeta join "", map { uc chr } (0..255)');
        add_trials('LC_CTYPE', 'quotemeta join "", map { CORE::fc chr } (0..255)');
        add_trials('LC_CTYPE', 'my $string = join "", map { chr } 0..255; $string =~ s|(.)|$1=~/\d/?1:0|gers');
        add_trials('LC_CTYPE', 'my $string = join "", map { chr } 0..255; $string =~ s|(.)|$1=~/\s/?1:0|gers');
        add_trials('LC_CTYPE', 'my $string = join "", map { chr } 0..255; $string =~ s|(.)|$1=~/\w/?1:0|gers');
        add_trials('LC_CTYPE', 'my $string = join "", map { chr } 0..255; $string =~ s|(.)|$1=~/[[:alpha:]]/?1:0|gers');
        add_trials('LC_CTYPE', 'my $string = join "", map { chr } 0..255; $string =~ s|(.)|$1=~/[[:alnum:]]/?1:0|gers');
        add_trials('LC_CTYPE', 'my $string = join "", map { chr } 0..255; $string =~ s|(.)|$1=~/[[:ascii:]]/?1:0|gers');
        add_trials('LC_CTYPE', 'my $string = join "", map { chr } 0..255; $string =~ s|(.)|$1=~/[[:blank:]]/?1:0|gers');
        add_trials('LC_CTYPE', 'my $string = join "", map { chr } 0..255; $string =~ s|(.)|$1=~/[[:cntrl:]]/?1:0|gers');
        add_trials('LC_CTYPE', 'my $string = join "", map { chr } 0..255; $string =~ s|(.)|$1=~/[[:graph:]]/?1:0|gers');
        add_trials('LC_CTYPE', 'my $string = join "", map { chr } 0..255; $string =~ s|(.)|$1=~/[[:lower:]]/?1:0|gers');
        add_trials('LC_CTYPE', 'my $string = join "", map { chr } 0..255; $string =~ s|(.)|$1=~/[[:print:]]/?1:0|gers');
        add_trials('LC_CTYPE', 'my $string = join "", map { chr } 0..255; $string =~ s|(.)|$1=~/[[:punct:]]/?1:0|gers');
        add_trials('LC_CTYPE', 'my $string = join "", map { chr } 0..255; $string =~ s|(.)|$1=~/[[:upper:]]/?1:0|gers');
        add_trials('LC_CTYPE', 'my $string = join "", map { chr } 0..255; $string =~ s|(.)|$1=~/[[:xdigit:]]/?1:0|gers');
        add_trials('LC_CTYPE', $langinfo_LC_CTYPE);
        add_trials('LC_CTYPE', 'POSIX::mblen(chr 0x100)');
        add_trials('LC_CTYPE', 'my $value; POSIX::mbtowc($value, chr 0x100); $value;');
        add_trials('LC_CTYPE', 'my $value; POSIX::wctomb($value, 0x100); $value;');
        add_trials('LC_CTYPE', $case_insensitive_matching_test);
        next;
    }

    if ($category eq 'LC_MESSAGES') {
        add_trials('LC_MESSAGES', "join \"\n\", map { \$! = \$_, \"\$!\" } ($msg_catalog)");
        add_trials('LC_MESSAGES', $langinfo_LC_MESSAGES);
        next;
    }

    if ($category eq 'LC_MONETARY') {
        add_trials('LC_MONETARY', "localeconv()->{currency_symbol}");
        add_trials('LC_MONETARY', $langinfo_LC_MONETARY);
        next;
    }

    if ($category eq 'LC_NUMERIC') {
        add_trials('LC_NUMERIC', "localeconv()->{decimal_point}");
        add_trials('LC_NUMERIC', $langinfo_LC_NUMERIC);

        # Use a variable to avoid constant folding hiding real bugs
        add_trials('LC_NUMERIC', 'my $in = 4.2; sprintf("%g", $in)');
        next;
    }

    if ($category eq 'LC_TIME') {
        add_trials('LC_TIME', "POSIX::strftime($strftime_args)");
        add_trials('LC_TIME', $langinfo_LC_TIME);
        next;
    }
}

#print STDERR __FILE__, __LINE__, ": ", Dumper \%tests_prep;
#_END__

my @tests;
for my $i (1 .. $thread_count) {
    foreach my $category (sort keys %tests_prep) {
        foreach my $locale (sort C_first keys $tests_prep{$category}->%*) {
            next if $locale eq 'duplicate_results';
            foreach my $op (sort keys $tests_prep{$category}{$locale}->%*) {
                my $expected = $tests_prep{$category}{$locale}{$op};
                my %temp = ( op => $op,
                             expected => $expected
                           );
                $tests[$i]->{$category}{locale_name} = $locale;
                push $tests[$i]->{$category}{locale_tests}->@*, \%temp;
            }
            delete $tests_prep{$category}{$locale};
            last;
        }

        if (! exists $tests[$i]->{$category}{locale_tests}) {
            #print STDERR __FILE__, ": ", __LINE__, ": i=$i $category: missing tests\n";
            #print STDERR __FILE__, ": ", __LINE__, ": ", Dumper $tests_prep{$category}{duplicate_results};
            foreach my $op (sort keys $tests_prep{$category}{duplicate_results}->%*) {
                my $locale_result_pair = shift $tests_prep{$category}{duplicate_results}{$op}->@*;
                next unless $locale_result_pair;

                my $locale = $locale_result_pair->[0];
                my $expected = $locale_result_pair->[1];
                $tests[$i]->{$category}{locale_name} = $locale;
                my %temp = ( op => $op,
                             expected => $expected
                           );
                #print STDERR __FILE__, ": ", __LINE__, ": ", Dumper \%temp ; #if $locale eq "es_CO.utf8" && $category eq 'LC_TIME';
                #print STDERR __FILE__, ": ", __LINE__, ": ", Dumper $tests[$i]->{$category}{locale_tests} ; #if $locale eq "es_CO.utf8" && $category eq 'LC_TIME';
                push $tests[$i]->{$category}{locale_tests}->@*, \%temp;
                #print STDERR __FILE__, ": ", __LINE__, ": ", Dumper $tests[$i]->{$category}{locale_tests} ; #if $locale eq "es_CO.utf8" && $category eq 'LC_TIME';
                # Conserve our resources by only consuming one of the things
                # we have in our reserves; the purpose here is to make sure
                # this category has at least one test.  (The logic just above
                # assumes we only do one; otherwise it can get wrong tests
                # pushed.)
                last;
           }
        }

        # If still didn't get any results, as a last resort copy the previous
        # one.
        if (! exists $tests[$i]->{$category}{locale_tests}) {
              last unless    $i > 0
                          && defined $tests[$i-1]->{$category}{locale_name};
              $tests[$i  ]->{$category}{locale_name}
            = $tests[$i-1]->{$category}{locale_name};

              $tests[$i  ]->{$category}{locale_tests}
            = $tests[$i-1]->{$category}{locale_tests};
#print STDERR __FILE__, ": ", __LINE__, ": ", Dumper $category, $i, $tests[$i  ]->{$category};
        }
    }
}

#print STDERR __FILE__, ": ", __LINE__, ": ", Dumper \@tests;
#__END__

my $tests_expanded = Data::Dumper->Dump([ \@tests ], [ 'all_tests_ref' ]);
my $starting_time = sprintf "%.16e", (time() + 1) * 1_000_000;

    {
        # See if multiple threads can simultaneously change the locale, and give
        # the expected radix results.  On systems without a comma radix locale,
        # run this anyway skipping the use of that, to verify that we dont
        # segfault
        fresh_perl_is("
            use threads;
            use strict;
            use warnings;
            use POSIX qw(locale_h);
            use utf8;
            use Time::HiRes qw(time usleep);

            use Devel::Peek;

            my \$result = 1;
            my \@threads = map +threads->create(sub {
                #print STDERR 'thread ', threads->tid, ' started, sleeping ', $starting_time - time() * 1_000_000, \" usec\\n\";
                my \$sleep_time = $starting_time - time() * 1_000_000;
                usleep(\$sleep_time) if \$sleep_time > 0;
                threads->yield();

                #print STDERR 'thread ', threads->tid, \" taking off\\n\";

                my \$i = shift;

                my $tests_expanded;

                # Tests for just this thread
                my \$thread_tests_ref = \$all_tests_ref->[\$i];

                my \%corrects;

                foreach my \$category_name (sort keys \$thread_tests_ref->%*) {
                    my \$cat_num = eval \"&POSIX::\$category_name\";
                    print STDERR \"\$@\\n\" if \$@;

                    my \$locale = \$thread_tests_ref->{\$category_name}{locale_name};
                    setlocale(\$cat_num, \$locale);
                    \$corrects{\$category_name} = 0;
                }

                use locale;

                for my \$iteration (1..$iterations) {
	    	    my \$errors = 0;
                    for my \$category_name (sort keys \$thread_tests_ref->%*) {
                        foreach my \$test (\$thread_tests_ref->{\$category_name}{locale_tests}->@*) {
                            my \$expected = \$test->{expected};
                            my \$got = eval \$test->{op};
                            if (\$got eq \$expected) {
                                \$corrects{\$category_name}++;
                            }
                            else {
                                \$|=1;
				\$errors++;
                                my \$locale
                                        = \$thread_tests_ref->{\$category_name}
                                                              {locale_name};
                                print STDERR \"thread \", threads->tid(),
                                             \" failed in iteration \$iteration\",
                                             \" for locale \$locale:\",
                                             \" \$category_name\",
                                             \" op='\$test->{op}'\",
                                             \" after getting\",
                                             \" \$corrects{\$category_name}\", 
                                             \" previous corrects\n\";
                                print STDERR \"expected\";
                                if (utf8::is_utf8(\$expected)) {
                                    print STDERR \" (already was UTF-8)\";
                                }
                                else {
                                    utf8::upgrade(\$expected);
                                    print STDERR \" (converted to UTF-8)\";
                                }
                                print STDERR \":\\n\";
                                Dump \$expected;

                                print STDERR \"\\ngot\";
                                if (utf8::is_utf8(\$got)) {
                                    print STDERR \" (already was UTF-8)\";
                                }
                                else {
                                    utf8::upgrade(\$got);
                                    print STDERR \" (converted to UTF-8)\";
                                }
                                print STDERR \":\\n\";
                                Dump \$got;
                            }
                        }
                    }

		    return 0 if \$errors;
                }

                return 1;

            }, \$_), (1..$thread_count);
        \$result &= \$_->join for splice \@threads;
        print \$result",
    1, {}, "Verify there were no failures with simultaneous running threads"
    );
}

done_testing();
