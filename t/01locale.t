#!/usr/bin/perl
# test locale

use Test::More tests => 9;

BEGIN  {
   use_ok('POSIX', ':locale_h', 'setlocale');
}

my $default = setlocale(LC_MESSAGES) || 'none';
ok(1, "default locale: $default");

$! = 2;
my $err_en = "$!";
ok(defined $err_en, $err_en);  # platform dependent
my $try = setlocale LC_MESSAGES, 'nl_NL';
ok(defined $try, 'defined return');
is($try, 'nl_NL');

is(setlocale(LC_MESSAGES), 'nl_NL');
$! = 2;
my $err_nl = "$!";
ok(defined $err_nl, $err_nl);
isnt($err_en, $err_nl);

setlocale(LC_MESSAGES, 'en_US');
$! = 2;
my $err_en2 = "$!";
is($err_en, $err_en2, $err_en2);
