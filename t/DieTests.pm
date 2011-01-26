package DieTests;
use warnings;
use strict;

use Log::Report::Die qw/die_decode/;
use Carp;

use Test::More tests => 13;
use DieTests;

$! = 3;
my $errno  = $!+0;
my $errstr = "$!";

sub process($)
{   my ($err, $opt, $reason, $message) = die_decode shift;
    $err =~ s/\d+\.?$/XX/;
    my $errno = $opt->{errno}    || 'no errno';
    my $loc   = $opt->{location};
    my $loca  = $loc ? "$loc->[1]#XX" : 'no location';
    my $stack = join "\n",
                    map { join '#', $_->[0], $_->[1], 'XX' }
                        @{$opt->{stack}};
    <<__RESULT
$reason: $message ($errno)
$err
$loca
$stack
__RESULT
}

sub run_tests()
{

ok(1, "err $errno is '$errstr'");

# die

eval { die "ouch" };
my $die_text1 = $@;
is(process($die_text1),  <<__OUT, "die");
ERROR: ouch (no errno)
ouch at t/DieTests.pm line XX
t/DieTests.pm#XX

__OUT

eval { die "ouch\n" };
my $die_text2 = $@;
is(process($die_text2),  <<__OUT, "die");
ERROR: ouch (no errno)
ouch
no location

__OUT

eval { $! = $errno; die "ouch $!" };
my $die_text3 = $@;
is(process($die_text3),  <<__OUT, "die");
FAULT: ouch (3)
ouch No such process at t/DieTests.pm line XX
t/DieTests.pm#XX

__OUT

eval { $! = $errno; die "ouch $!\n" };
my $die_text4 = $@;
is(process($die_text4),  <<__OUT, "die");
FAULT: ouch (3)
ouch No such process
no location

__OUT

# croak

eval { croak "ouch" };
my $croak_text1 = $@;
is(process($croak_text1),  <<__OUT, "croak");
ERROR: ouch (no errno)
ouch at t/41die.t line XX
t/41die.t#XX

__OUT

eval { croak "ouch\n" };
my $croak_text2 = $@;
is(process($croak_text2),  <<__OUT, "croak");
ERROR: ouch (no errno)
ouch
t/41die.t#XX

__OUT

eval { $! = $errno; croak "ouch $!" };
my $croak_text3 = $@;
is(process($croak_text3),  <<__OUT, "croak");
FAULT: ouch (3)
ouch No such process at t/41die.t line XX
t/41die.t#XX

__OUT

eval { $! = $errno; croak "ouch $!\n" };
my $croak_text4 = $@;
is(process($croak_text4),  <<__OUT, "croak");
FAULT: ouch (3)
ouch No such process
t/41die.t#XX

__OUT

# confess

eval { confess "ouch" };
my $confess_text1 = $@;
is(process($confess_text1),  <<__OUT, "confess");
PANIC: ouch (no errno)
ouch at t/DieTests.pm line XX
t/DieTests.pm#XX
eval {...}#t/DieTests.pm#XX
DieTests::run_tests()#t/41die.t#XX
main::simple_wrapper()#t/41die.t#XX
__OUT

eval { confess "ouch\n" };
my $confess_text2 = $@;
is(process($confess_text2),  <<__OUT, "confess");
PANIC: ouch (no errno)
ouch
t/DieTests.pm#XX
eval {...}#t/DieTests.pm#XX
DieTests::run_tests()#t/41die.t#XX
main::simple_wrapper()#t/41die.t#XX
__OUT

eval { $! = $errno; confess "ouch $!" };
my $confess_text3 = $@;
is(process($confess_text3),  <<__OUT, "confess");
ALERT: ouch (3)
ouch No such process at t/DieTests.pm line XX
t/DieTests.pm#XX
eval {...}#t/DieTests.pm#XX
DieTests::run_tests()#t/41die.t#XX
main::simple_wrapper()#t/41die.t#XX
__OUT


if($^O eq 'Win32')
{   # perl bug http://rt.perl.org/rt3/Ticket/Display.html?id=81586
    pass 'Win32/confess bug #81586';
}
else
{

eval { $! = $errno; confess "ouch $!\n" };
my $confess_text4 = $@;
is(process($confess_text4),  <<__OUT, "confess");
ALERT: ouch (3)
ouch No such process
t/DieTests.pm#XX
eval {...}#t/DieTests.pm#XX
DieTests::run_tests()#t/41die.t#XX
main::simple_wrapper()#t/41die.t#XX
__OUT

}

}  # run_tests()

1;
